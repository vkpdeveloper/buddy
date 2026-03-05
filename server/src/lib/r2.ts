import { randomUUID } from 'crypto';
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { env } from './env';

const signedUrlExpirySeconds = 60 * 60 * 24;

export const r2Client = new S3Client({
  region: 'auto',
  endpoint: `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: env.R2_ACCESS_KEY_ID,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY,
  },
});

function fileExtFromMimeType(mimeType: string): string {
  switch (mimeType) {
    case 'image/jpeg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    default:
      return 'bin';
  }
}

export function createProgressPhotoObjectKey(mimeType: string): string {
  const now = Date.now();
  const ext = fileExtFromMimeType(mimeType);
  return `growth/photos/${now}-${randomUUID()}.${ext}`;
}

export async function uploadPrivateObject(params: {
  objectKey: string;
  body: Uint8Array;
  contentType: string;
}) {
  await r2Client.send(
    new PutObjectCommand({
      Bucket: env.R2_BUCKET_NAME,
      Key: params.objectKey,
      Body: params.body,
      ContentType: params.contentType,
      ACL: 'private',
    }),
  );
}

export async function signPrivateObjectUrl(objectKey: string): Promise<string> {
  return getSignedUrl(
    r2Client,
    new GetObjectCommand({
      Bucket: env.R2_BUCKET_NAME,
      Key: objectKey,
    }),
    { expiresIn: signedUrlExpirySeconds },
  );
}
