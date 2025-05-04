// #region Authentication & RBAC
/**
 * Interface for user authentication and role-based access control.
 * TODO[roadmap]: Integrate with real authentication provider.
 */
export interface AuthUser {
  id: string;
  roles: string[];
  token?: string;
}

import * as fs from 'fs';
import * as path from 'path';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';

const USERS_PATH = path.resolve(__dirname, 'users.json');
const JWT_SECRET = process.env.JWT_SECRET || 'changeme';

function loadUsers(): AuthUser[] {
  if (fs.existsSync(USERS_PATH)) {
    try {
      return JSON.parse(fs.readFileSync(USERS_PATH, 'utf-8'));
    } catch {
      return [];
    }
  }
  return [];
}
function saveUsers(users: AuthUser[]) {
  fs.writeFileSync(USERS_PATH, JSON.stringify(users, null, 2));
}

const users: AuthUser[] = loadUsers();

/**
 * Register a new user with hashed password.
 */
export async function registerUser(id: string, password: string, roles: string[] = []): Promise<AuthUser> {
  const hashed = await bcrypt.hash(password, 10);
  const user: AuthUser = { id, roles, token: hashed };
  users.push(user);
  saveUsers(users);
  return user;
}

/**
 * Login a user and return a JWT if successful.
 */
export async function loginUser(id: string, password: string): Promise<string | null> {
  const user = users.find(u => u.id === id);
  if (!user) return null;
  const match = await bcrypt.compare(password, user.token || '');
  if (!match) return null;
  const token = jwt.sign({ id: user.id, roles: user.roles }, JWT_SECRET, { expiresIn: '1h' });
  return token;
}

/**
 * Authenticate a user by verifying JWT.
 */
export function authenticate(token: string): AuthUser | null {
  try {
    const payload = jwt.verify(token, JWT_SECRET) as { id: string; roles: string[] };
    const user = users.find(u => u.id === payload.id);
    if (!user) return null;
    return { ...user, roles: payload.roles };
  } catch {
    return null;
  }
}

/**
 * Add a user (stub).
 * @param user - The user to add
 */
export function addUser(user: AuthUser) {
  users.push(user);
}
// #endregion 