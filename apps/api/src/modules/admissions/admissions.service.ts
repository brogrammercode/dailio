import { ulid } from 'ulid';

import { prisma } from '../../lib/prisma';
import { ConflictError, NotFoundError } from '../../lib/errors';
import { notify } from '../notifications/notifications.service';

import type { CreateJoinRequestInput, JoinRequestActionInput } from './admissions.schema';

async function branchJoinReviewerUserIds(organizationId: string, branchId: string) {
  const members = await prisma.member.findMany({
    where: { organization_id: organizationId, branch_id: branchId, status: 'ACTIVE' },
    select: {
      user_id: true,
      role: { select: { system_key: true, permissions: true } },
      role_assignments: {
        where: {
          organization_id: organizationId,
          branch_id: branchId,
          effective_from: { lte: new Date() },
          OR: [{ effective_to: null }, { effective_to: { gt: new Date() } }],
        },
        select: { role: { select: { system_key: true, permissions: true } } },
      },
    },
  });

  return members
    .filter((member) => {
      const roles = [
        member.role,
        ...member.role_assignments.map((assignment) => assignment.role),
      ].filter((role): role is NonNullable<typeof role> => role != null);
      return roles.some(
        (role) => role.system_key === 'OWNER' || role.permissions.includes('JOIN_REQUEST_READ'),
      );
    })
    .map((member) => member.user_id);
}

export async function submitJoinRequest(
  user_id: string,
  branch_id: string,
  data: CreateJoinRequestInput,
) {
  const branch = await prisma.branch.findUnique({
    where: { id: branch_id },
    include: { organization: true },
  });

  if (!branch) throw new NotFoundError('Branch');

  // Check if they are already a member or have a pending request
  const existingMember = await prisma.member.findFirst({
    where: { branch_id, user_id },
  });
  if (existingMember) throw new ConflictError('Already a member of this branch');

  const existingRequest = await prisma.joinRequest.findFirst({
    where: { user_id, branch_id, status: 'PENDING' },
  });
  if (existingRequest) throw new ConflictError('A pending join request already exists');

  const request = await prisma.joinRequest.create({
    data: {
      id: ulid(),
      user_id,
      branch_id,
      organization_id: branch.organization_id,
      status: 'PENDING',
      message: data.message,
    },
  });

  try {
    const reviewerUserIds = await branchJoinReviewerUserIds(branch.organization_id, branch_id);
    await notify({
      type: 'JOIN_REQUEST_SUBMITTED',
      organizationId: branch.organization_id,
      branchId: branch_id,
      actorUserId: user_id,
      entityType: 'JoinRequest',
      entityId: request.id,
      recipientUserIds: reviewerUserIds.filter((id) => id !== user_id),
      title: 'New join request',
      body: 'A user requested to join your branch.',
      data: { organization_id: branch.organization_id, branch_id, entity_id: request.id },
      dedupeKey: `join-request:${request.id}:submitted`,
    });
  } catch {
    // Notification delivery must not undo a successfully-created request.
  }

  return request;
}

export async function listPendingRequests(organization_id: string, branch_id: string) {
  return prisma.joinRequest.findMany({
    where: {
      organization_id,
      branch_id,
      status: 'PENDING',
    },
    include: {
      user: {
        select: { id: true, name: true, email: true },
      },
    },
    orderBy: { created_at: 'asc' },
  });
}

export async function approveJoinRequest(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  request_id: string,
  data: JoinRequestActionInput,
) {
  const approvedMember = await (async () => {
    try {
      return await prisma.$transaction(
        async (tx) => {
          const txClient = tx as typeof prisma;
          const request = await txClient.joinRequest.findUnique({
            where: { id: request_id },
            include: { user: true },
          });

          if (
            !request ||
            request.organization_id !== organization_id ||
            request.branch_id !== branch_id
          ) {
            throw new NotFoundError('Join Request');
          }
          if (request.status !== 'PENDING') {
            throw new ConflictError('Request is not pending');
          }

          // 1. Fetch the configured default MEMBER role. It may be organization-wide
          // or scoped to this branch, but it must belong to this tenant.
          const memberRole = await txClient.role.findFirst({
            where: {
              organization_id,
              system_key: 'MEMBER',
              OR: [{ branch_id }, { branch_id: null }],
            },
            orderBy: { branch_id: 'desc' },
          });

          // 2. Reuse an existing membership if a retry/concurrent approval already
          // created it. Serializable isolation prevents two approvals from both
          // creating a membership for the same request.
          const existingMember = await txClient.member.findUnique({
            where: {
              organization_id_branch_id_user_id: {
                organization_id,
                branch_id,
                user_id: request.user_id,
              },
            },
          });
          const member = existingMember
            ? await txClient.member.update({
                where: { id: existingMember.id },
                data: { role_id: memberRole?.id ?? existingMember.role_id, status: 'ACTIVE' },
              })
            : await txClient.member.create({
                data: {
                  id: ulid(),
                  user_id: request.user_id,
                  organization_id,
                  branch_id,
                  role_id: memberRole?.id,
                  // ULID suffix is unique without exposing a sequential member count.
                  member_number: 'MEM-' + ulid().slice(-8),
                  status: 'ACTIVE',
                  is_employee: false,
                },
              });

          if (memberRole?.id) {
            const existingAssignment = await txClient.memberRoleAssignment.findFirst({
              where: { member_id: member.id, role_id: memberRole.id, effective_to: null },
            });
            if (!existingAssignment) {
              await txClient.memberRoleAssignment.create({
                data: {
                  id: ulid(),
                  organization_id,
                  branch_id,
                  member_id: member.id,
                  role_id: memberRole.id,
                  priority: 0,
                  updated_at: new Date(),
                },
              });
            }
          }

          // 3. Mark request as APPROVED only after the membership exists.
          await txClient.joinRequest.update({
            where: { id: request_id },
            data: {
              status: 'APPROVED',
              reviewed_at: new Date(),
              reviewed_by: actor_id,
            },
          });

          // Link member to request
          await txClient.joinRequest.update({
            where: { id: request_id },
            data: { member_id: member.id },
          });

          // 4. Audit log
          await txClient.auditLog.create({
            data: {
              id: ulid(),
              organization_id,
              branch_id,
              actor_id,
              action: 'UPDATE',
              target_type: 'JoinRequest',
              target_id: request_id,
              after_state: { status: 'APPROVED', reason: data.reason },
            },
          });

          return member;
        },
        { maxWait: 5000, timeout: 20000 },
      );
    } catch (error) {
      // A stale database with the historical full unique constraint, or a
      // concurrent approval against the same request, can surface P2002 while
      // the desired state is already committed. Treat that retry as success
      // only after re-reading the same tenant/branch/request scope.
      if ((error as { code?: string }).code !== 'P2002') throw error;
      const committed = await prisma.joinRequest.findFirst({
        where: {
          id: request_id,
          organization_id,
          branch_id,
          status: 'APPROVED',
        },
        select: { member_id: true },
      });
      if (!committed?.member_id) throw error;
      const member = await prisma.member.findFirst({
        where: {
          id: committed.member_id,
          organization_id,
          branch_id,
          status: 'ACTIVE',
        },
      });
      if (!member) throw error;
      return member;
    }
  })();

  // ── After transaction: send FCM + in-app notification (best-effort) ──
  try {
    const approvedBranch = await prisma.branch.findUnique({
      where: { id: branch_id },
      select: { name: true },
    });

    await notify({
      type: 'JOIN_REQUEST_APPROVED',
      organizationId: organization_id,
      branchId: branch_id,
      actorUserId: actor_id,
      entityType: 'JoinRequest',
      entityId: request_id,
      recipientUserIds: [approvedMember.user_id],
      title: 'Join request approved',
      body: `Your request to join ${approvedBranch?.name ?? 'the branch'} has been approved. You are now an active member.`,
      data: { organization_id, branch_id, entity_id: request_id },
      dedupeKey: `join-request:${request_id}:approved`,
    });

    return approvedMember;

    // Persist in-app notification
    /* await prisma.notification.create({
      data: {
        id: ulid(),
        user_id: approvedMember.user_id,
        organization_id,
        title: 'Join Request Approved! 🎉',
        body: `Your request to join ${approvedBranch?.name ?? 'the branch'} has been approved. You are now an active member.`,
        channel: 'IN_APP',
        status: 'SENT',
        sent_at: new Date(),
      },
    }); */

    // Send push notification
    /* const messaging = null;
    const pushToken = approvedUser?.fcm_token;
    if (messaging && pushToken) {
        await messaging!.send({
          token: pushToken!,
          notification: {
            title: 'Join Request Approved! 🎉',
            body: `Your request to join ${approvedBranch?.name ?? 'the branch'} has been approved.`,
          },
          data: { type: 'JOIN_APPROVED', organization_id, branch_id },
        });
    } */
  } catch {
    // Best-effort — never fail the main operation for a notification
  }

  return approvedMember;
}

export async function rejectJoinRequest(
  actor_id: string,
  organization_id: string,
  branch_id: string,
  request_id: string,
  data: JoinRequestActionInput,
) {
  const rejected = await prisma.$transaction(async (tx) => {
    const txClient = tx as typeof prisma;
    const request = await txClient.joinRequest.findUnique({
      where: { id: request_id },
    });

    if (
      !request ||
      request.organization_id !== organization_id ||
      request.branch_id !== branch_id
    ) {
      throw new NotFoundError('Join Request');
    }
    if (request.status !== 'PENDING') {
      throw new ConflictError('Request is not pending');
    }

    const updated = await txClient.joinRequest.update({
      where: { id: request_id },
      data: {
        status: 'REJECTED',
        rejection_reason: data.reason,
        reviewed_at: new Date(),
        reviewed_by: actor_id,
      },
    });

    await txClient.auditLog.create({
      data: {
        id: ulid(),
        organization_id,
        branch_id,
        actor_id,
        action: 'UPDATE',
        target_type: 'JoinRequest',
        target_id: request_id,
        after_state: { status: 'REJECTED', reason: data.reason },
      },
    });

    return updated;
  });

  try {
    await notify({
      type: 'JOIN_REQUEST_REJECTED',
      organizationId: organization_id,
      branchId: branch_id,
      actorUserId: actor_id,
      entityType: 'JoinRequest',
      entityId: request_id,
      recipientUserIds: [rejected.user_id],
      title: 'Join request not approved',
      body: data.reason
        ? `Your request to join this branch was not approved: ${data.reason}`
        : 'Your request to join this branch was not approved.',
      data: { organization_id, branch_id, entity_id: request_id },
      dedupeKey: `join-request:${request_id}:rejected`,
    });
  } catch {
    // Notification delivery must not undo the rejection.
  }

  return rejected;
}
