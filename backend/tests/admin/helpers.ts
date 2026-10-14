import type { DashboardStored } from '../../src/modules/admin/dashboard.types.js';
import { aggregate } from '../analytics/helpers.js';

export function dashboardStored(): DashboardStored {
  return {
    scans: aggregate(),
    farmers: { total: 3, active: 1, suspended: 1, deactivated: 1 },
    ownership: { authenticated: 5, anonymous: 3 },
    productionCount: 0,
    productionVersions: [],
    recent: [],
  };
}
