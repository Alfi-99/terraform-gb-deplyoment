/**
 * Lambda POST Handler
 * Menangani semua request yang memodifikasi data: POST, PUT, DELETE
 *
 * Fitur:
 * - Semua request dan response di-log ke DynamoDB
 * - Error handling lengkap
 * - Input validation
 * - Transaction support
 */

const { log, logApiRequest } = require('/opt/nodejs/dynamodb-logger');
const { query, transaction } = require('/opt/nodejs/db-connection');
const { success, error, cors } = require('/opt/nodejs/response-helper');

const SERVICE_ID = `lambda-post-${process.env.AWS_REGION || 'ap-southeast-1'}`;

/**
 * Main handler
 */
exports.handler = async (event) => {
  const startTime = Date.now();
  const requestId = event.requestContext?.requestId || `req-${Date.now()}`;
  const httpMethod = event.httpMethod || 'UNKNOWN';
  const path = event.path || '/';
  const sourceIp = event.requestContext?.identity?.sourceIp || 'unknown';
  const userAgent = event.headers?.['User-Agent'] || 'unknown';

  // Log request masuk
  await log(SERVICE_ID, 'INFO', `Request diterima: ${httpMethod} ${path}`, {
    requestId,
    sourceIp,
    userAgent,
    pathParameters: event.pathParameters,
    queryStringParameters: event.queryStringParameters,
  }, requestId);

  try {
    // Handle CORS preflight
    if (httpMethod === 'OPTIONS') {
      return cors();
    }

    let result;
    const pathParameters = event.pathParameters || {};
    const body = event.body ? JSON.parse(event.body) : {};

    // Routing berdasarkan method dan path
    if (httpMethod === 'POST' && path.includes('/items')) {
      result = await handleCreateItem(body, requestId);
    } else if (httpMethod === 'PUT' && path.includes('/items/')) {
      result = await handleUpdateItem(pathParameters.id, body, requestId);
    } else if (httpMethod === 'DELETE' && path.includes('/items/')) {
      result = await handleDeleteItem(pathParameters.id, requestId);
    } else {
      result = error('Endpoint tidak ditemukan', 404);
    }

    // Log response
    const duration = Date.now() - startTime;
    await logApiRequest({
      requestId,
      endpoint: path,
      httpMethod,
      statusCode: result.statusCode,
      durationMs: duration,
      ipAddress: sourceIp,
      userAgent,
      requestBody: body,
    });

    await log(SERVICE_ID, 'INFO', `Request selesai: ${httpMethod} ${path} - ${result.statusCode}`, {
      requestId,
      durationMs: duration,
      statusCode: result.statusCode,
    }, requestId);

    return result;

  } catch (err) {
    const duration = Date.now() - startTime;

    // Log error ke DynamoDB
    await log(SERVICE_ID, 'ERROR', `Error pada ${httpMethod} ${path}: ${err.message}`, {
      requestId,
      errorName: err.name,
      errorStack: err.stack,
      durationMs: duration,
    }, requestId);

    await logApiRequest({
      requestId,
      endpoint: path,
      httpMethod,
      statusCode: 500,
      durationMs: duration,
      ipAddress: sourceIp,
      userAgent,
      errorMessage: err.message,
    });

    return error('Terjadi kesalahan internal server', 500, {
      errorId: requestId,
      message: err.message,
    });
  }
};

/**
 * Handler: Buat item baru
 */
async function handleCreateItem(body, requestId) {
  // Auto-initialize table if not exists
  try {
    await query('CREATE DATABASE IF NOT EXISTS gbappdb');
    await query('USE gbappdb');
    await query(`
      CREATE TABLE IF NOT EXISTS items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);
  } catch (e) {
    await log(SERVICE_ID, 'ERROR', `AUTO-INIT FAILED: ${e.message}`, { 
      requestId, 
      stack: e.stack 
    }, requestId);
  }

  // Validasi input
  if (!body.name || !body.description) {
    await log(SERVICE_ID, 'WARN', 'Validasi gagal: name dan description wajib diisi', {
      requestId,
      body,
    }, requestId);
    return error('name dan description wajib diisi', 400);
  }

  const result = await transaction(async (conn) => {
    const [insertResult] = await conn.execute(
      'INSERT INTO items (name, description, created_at, updated_at) VALUES (?, ?, NOW(), NOW())',
      [body.name, body.description]
    );

    const [newItem] = await conn.execute(
      'SELECT * FROM items WHERE id = ?',
      [insertResult.insertId]
    );

    return newItem[0];
  });

  await log(SERVICE_ID, 'INFO', `Item baru berhasil dibuat: ID ${result.id}`, {
    requestId,
    itemId: result.id,
    itemName: result.name,
  }, requestId);

  return success(result, 201, 'Item berhasil dibuat');
}

/**
 * Handler: Update item
 */
async function handleUpdateItem(itemId, body, requestId) {
  if (!itemId) {
    return error('ID item wajib diisi', 400);
  }

  // Cek apakah item ada
  const existingItems = await query('SELECT id FROM items WHERE id = ?', [itemId]);
  if (existingItems.length === 0) {
    await log(SERVICE_ID, 'WARN', `Item ID ${itemId} tidak ditemukan untuk update`, { requestId }, requestId);
    return error(`Item dengan ID ${itemId} tidak ditemukan`, 404);
  }

  const updateFields = [];
  const updateValues = [];

  if (body.name) {
    updateFields.push('name = ?');
    updateValues.push(body.name);
  }
  if (body.description) {
    updateFields.push('description = ?');
    updateValues.push(body.description);
  }

  if (updateFields.length === 0) {
    return error('Tidak ada field yang diupdate', 400);
  }

  updateFields.push('updated_at = NOW()');
  updateValues.push(itemId);

  await query(
    `UPDATE items SET ${updateFields.join(', ')} WHERE id = ?`,
    updateValues
  );

  const [updatedItem] = await query('SELECT * FROM items WHERE id = ?', [itemId]);

  await log(SERVICE_ID, 'INFO', `Item ID ${itemId} berhasil diupdate`, {
    requestId,
    itemId,
    updatedFields: Object.keys(body),
  }, requestId);

  return success(updatedItem, 200, 'Item berhasil diupdate');
}

/**
 * Handler: Hapus item
 */
async function handleDeleteItem(itemId, requestId) {
  if (!itemId) {
    return error('ID item wajib diisi', 400);
  }

  const existingItems = await query('SELECT id, name FROM items WHERE id = ?', [itemId]);
  if (existingItems.length === 0) {
    return error(`Item dengan ID ${itemId} tidak ditemukan`, 404);
  }

  await query('DELETE FROM items WHERE id = ?', [itemId]);

  await log(SERVICE_ID, 'INFO', `Item ID ${itemId} berhasil dihapus`, {
    requestId,
    itemId,
    itemName: existingItems[0].name,
  }, requestId);

  return success(null, 200, `Item ${itemId} berhasil dihapus`);
}
