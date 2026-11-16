export interface CreateRoomRequest {
  readonly subgroupId: string;
  readonly title: string;
}

export type CreateRoomRequestErrorCode =
  | 'invalid-request'
  | 'missing-field'
  | 'invalid-type'
  | 'empty-value'
  | 'invalid-path-segment'
  | 'unexpected-field';

export type CreateRoomRequestField = 'request' | 'subgroupId' | 'title';

export class CreateRoomRequestValidationError extends Error {
  constructor(
    readonly code: CreateRoomRequestErrorCode,
    message: string,
    readonly field: CreateRoomRequestField,
  ) {
    super(message);
    this.name = 'CreateRoomRequestValidationError';
  }
}

/**
 * Validates and normalizes the client-controlled portion of room creation.
 * Identity fields such as userId and hostUid are intentionally not accepted;
 * the callable derives those from Firebase Authentication context.
 */
export function parseCreateRoomRequest(input: unknown): CreateRoomRequest {
  if (input === null || typeof input !== 'object' || Array.isArray(input)) {
    throw new CreateRoomRequestValidationError(
      'invalid-request',
      'Request data must be an object.',
      'request',
    );
  }

  const data = input as Record<string, unknown>;
  const allowedFields = new Set(['subgroupId', 'title']);
  for (const field of Object.keys(data)) {
    if (!allowedFields.has(field)) {
      throw new CreateRoomRequestValidationError(
        'unexpected-field',
        `Field "${field}" is not accepted.`,
        'request',
      );
    }
  }

  const subgroupId = readRequiredString(data, 'subgroupId');
  if (subgroupId.includes('/')) {
    throw new CreateRoomRequestValidationError(
      'invalid-path-segment',
      'subgroupId must not contain a slash.',
      'subgroupId',
    );
  }

  const title = readRequiredString(data, 'title');
  return { subgroupId, title };
}

function readRequiredString(
  data: Record<string, unknown>,
  field: 'subgroupId' | 'title',
): string {
  if (!Object.hasOwn(data, field)) {
    throw new CreateRoomRequestValidationError(
      'missing-field',
      `Field "${field}" is required.`,
      field,
    );
  }

  const value = data[field];
  if (typeof value !== 'string') {
    throw new CreateRoomRequestValidationError(
      'invalid-type',
      `Field "${field}" must be a string.`,
      field,
    );
  }

  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new CreateRoomRequestValidationError(
      'empty-value',
      `Field "${field}" must not be empty.`,
      field,
    );
  }

  return normalized;
}