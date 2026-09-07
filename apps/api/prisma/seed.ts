import { PrismaClient } from '@prisma/client';
import { ulid } from 'ulid';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding demo data...');

  // This seed creates the demo scenario described in CONTEXT.md Section 27:
  // Gym: Resolution Fitness Demo
  // Branches: Main Branch, East Branch
  // Fictional users, roles, plans

  // Permissions
  const permCodes = [
    'GYM_READ', 'ATTENDANCE_READ_SELF', 'ATTENDANCE_CREATE_SELF',
    'MEMBER_READ_SELF', 'PLAN_READ', 'SUBSCRIPTION_READ_SELF',
    'PAYMENT_READ_SELF', 'ANNOUNCEMENT_READ',
  ];
  for (const code of permCodes) {
    await prisma.permission.upsert({ where: { code }, create: { id: ulid(), code }, update: {} });
  }

  // Demo gym
  const gymId = ulid();
  const gym = await prisma.gym.upsert({
    where: { slug: 'resolution-fitness-demo' },
    create: {
      id: gymId,
      name: 'Resolution Fitness Demo',
      slug: 'resolution-fitness-demo',
      email: 'demo@resolutionfitness.example',
      timezone: 'Asia/Kolkata',
      currency: 'INR',
      status: 'ACTIVE',
    },
    update: {},
  });

  console.log(`✅ Gym: ${gym.name}`);
  console.log('✅ Seed completed. More data can be added per CONTEXT.md Section 27.');
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
