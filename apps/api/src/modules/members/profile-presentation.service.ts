import { prisma } from '../../lib/prisma';

type RecordValue = Record<string, unknown>;
const identityRelations = new Set(['user', 'actor', 'author', 'created_by']);
const immutableFields =
  /(snapshot|metadata|response)$|^(content|content_json|body|before_state|after_state|evidence|attachments|payload|earnings|deductions)$/;

function isRecord(value: unknown): value is RecordValue {
  return (
    value !== null &&
    typeof value === 'object' &&
    !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype
  );
}

/** Apply live organization identity fields only to selected user relations.
 * Never expand a response's field permissions or rewrite immutable snapshots.
 */
export async function presentOrganizationProfiles(organizationId: string, payload: unknown) {
  const users = new Set<string>();
  const memberIds = new Set<string>();
  const memberUsers = new Map<string, string>();
  function visit(
    value: unknown,
    transform?: (user: RecordValue, userId: string) => RecordValue,
    depth = 0,
  ): unknown {
    if (Array.isArray(value)) return value.map((item) => visit(item, transform, depth + 1));
    if (!isRecord(value)) return value;
    const result: RecordValue = {};
    for (const [key, child] of Object.entries(value)) {
      if (identityRelations.has(key) && isRecord(child) && typeof child.id === 'string') {
        users.add(child.id);
        result[key] = transform ? transform(child, child.id) : child;
      } else if (
        key === 'member' &&
        isRecord(child) &&
        typeof child.id === 'string' &&
        !Object.hasOwn(child, 'user') &&
        (Object.hasOwn(child, 'name') || Object.hasOwn(child, 'avatar_url'))
      ) {
        // Fee lists flatten the member presentation and retain a membership ID,
        // not the global user ID used by nested attendance rows.
        memberIds.add(child.id);
        const userId = memberUsers.get(child.id);
        result[key] = transform && userId ? transform(child, userId) : child;
      } else {
        result[key] =
          immutableFields.test(key) || (key === 'data' && depth > 0)
            ? child
            : visit(child, transform, depth + 1);
      }
    }
    return result;
  }
  visit(payload);
  if (memberIds.size) {
    const members = await prisma.member.findMany({
      where: { organization_id: organizationId, id: { in: [...memberIds] } },
      select: { id: true, user_id: true },
    });
    for (const member of members) {
      memberUsers.set(member.id, member.user_id);
      users.add(member.user_id);
    }
  }
  if (!users.size) return payload;
  const profiles = await prisma.organizationMemberProfile.findMany({
    where: { organization_id: organizationId, user_id: { in: [...users] } },
    select: { user_id: true, name: true, phone: true, avatar_url: true },
  });
  if (!profiles.length) return payload;
  const byUser = new Map(profiles.map((profile) => [profile.user_id, profile]));
  return visit(payload, (user, userId) => {
    const profile = byUser.get(userId);
    if (!profile) return user;
    const result = { ...user };
    for (const field of ['name', 'phone', 'avatar_url'] as const) {
      if (Object.hasOwn(user, field) && profile[field] !== null) result[field] = profile[field];
    }
    return result;
  });
}

export async function presentNotificationActors<
  T extends { organization_id: string | null; data: unknown },
>(notifications: T[]): Promise<T[]> {
  const result = [...notifications];
  const organizations = new Set(
    notifications.map((item) => item.organization_id).filter((id): id is string => id !== null),
  );
  for (const organizationId of organizations) {
    const ids = notifications
      .filter((item) => item.organization_id === organizationId)
      .flatMap((item) =>
        isRecord(item.data) && typeof item.data.actor_member_id === 'string'
          ? [item.data.actor_member_id]
          : [],
      );
    if (!ids.length) continue;
    const members = await prisma.member.findMany({
      where: { organization_id: organizationId, id: { in: ids } },
      select: { id: true, user_id: true },
    });
    const projected = (await presentOrganizationProfiles(organizationId, {
      data: members.map((member) => ({
        memberId: member.id,
        user: { id: member.user_id, name: null, avatar_url: null },
      })),
    })) as {
      data: Array<{ memberId: string; user: { name: string | null; avatar_url: string | null } }>;
    };
    const actors = new Map(projected.data.map((member) => [member.memberId, member.user]));
    for (const [index, item] of notifications.entries()) {
      if (item.organization_id !== organizationId || !isRecord(item.data)) continue;
      const actor = actors.get(item.data.actor_member_id as string);
      if (!actor) continue;
      result[index] = {
        ...item,
        data: {
          ...item.data,
          ...(actor.name !== null ? { actor_name: actor.name } : {}),
          ...(actor.avatar_url !== null ? { actor_avatar_url: actor.avatar_url } : {}),
        },
      };
    }
  }
  return result;
}
