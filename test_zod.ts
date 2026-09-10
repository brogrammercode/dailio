import { CreateOrganizationSchema, CreateLocationSchema } from './apps/api/src/modules/organizations/organizations.schema';

const orgData = {
  name: 'My Gym',
  timezone: 'Asia/Kolkata',
  currency: 'INR'
};

const locData = {
  name: 'Main Branch',
  address: 'Some Street',
  city: 'Some City',
  state: 'Some State',
  country: 'India',
  postal_code: '123456',
  latitude: 20.123,
  longitude: 78.123,
  timezone: 'Asia/Kolkata'
};

try {
  console.log('Org:', CreateOrganizationSchema.parse(orgData));
  console.log('Loc:', CreateLocationSchema.parse(locData));
} catch(e) {
  console.error(e.flatten());
}
