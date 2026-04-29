/**
 * Shared DynamoDB Logger
 * Digunakan oleh semua Lambda function untuk logging ke DynamoDB
 */

const { DynamoDBClient, PutItemCommand } = require('@aws-sdk/client-dynamodb');
const { marshall } = require('@aws-sdk/util-dynamodb');

const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'ap-southeast-1' });

/**
 * Hitung TTL Unix timestamp
 * @param {number} days - Berapa hari log disimpan
 * @returns {number} Unix timestamp
 */
function calculateTTL(days = 30) {
  const now = new Date();
  now.setDate(now.getDate() + days);
  return Math.floor(now.getTime() / 1000);
}

/**
 * Log pesan ke DynamoDB
 * @param {string} serviceId - Nama service (lambda-post, lambda-get, dll)
 * @param {string} logLevel - INFO, WARN, ERROR, DEBUG
 * @param {string} message - Pesan log
 * @param {object} metadata - Data tambahan (optional)
 * @param {string} requestId - Request ID untuk tracing
 */
async function log(serviceId, logLevel, message, metadata = {}, requestId = '') {
  const timestamp = new Date().toISOString();
  const ttlDays = parseInt(process.env.LOG_TTL_DAYS || '30');

  const logItem = {
    service_id: serviceId,
    timestamp: timestamp,
    log_level: logLevel,
    request_id: requestId || `${serviceId}-${Date.now()}`,
    message: message,
    metadata: JSON.stringify(metadata),
    environment: process.env.NODE_ENV || 'prod',
    function_version: process.env.AWS_LAMBDA_FUNCTION_VERSION || '$LATEST',
    expire_at: calculateTTL(ttlDays),
  };

  try {
    await dynamoClient.send(new PutItemCommand({
      TableName: process.env.DYNAMODB_LOG_TABLE,
      Item: marshall(logItem, { removeUndefinedValues: true }),
    }));
  } catch (err) {
    // Fallback ke console jika DynamoDB error (jangan throw agar tidak mengganggu main flow)
    console.error('[LOGGER ERROR] Gagal menulis log ke DynamoDB:', err.message);
    console.error('[FALLBACK LOG]', JSON.stringify(logItem));
  }
}

/**
 * Log API Request ke DynamoDB
 * @param {object} params - Parameter request log
 */
async function logApiRequest(params) {
  const {
    requestId,
    endpoint,
    httpMethod,
    statusCode,
    durationMs,
    userId = 'anonymous',
    ipAddress = 'unknown',
    userAgent = 'unknown',
    requestBody = null,
    errorMessage = null,
  } = params;

  const timestamp = new Date().toISOString();
  const ttlDays = parseInt(process.env.LOG_TTL_DAYS || '30');

  const requestLog = {
    request_id: requestId,
    timestamp: timestamp,
    endpoint: endpoint,
    http_method: httpMethod,
    status_code: String(statusCode),
    duration_ms: durationMs,
    user_id: userId,
    ip_address: ipAddress,
    user_agent: userAgent,
    request_body: requestBody ? JSON.stringify(requestBody) : null,
    error_message: errorMessage,
    environment: process.env.NODE_ENV || 'prod',
    expire_at: calculateTTL(ttlDays),
  };

  try {
    await dynamoClient.send(new PutItemCommand({
      TableName: process.env.DYNAMODB_API_TABLE,
      Item: marshall(requestLog, { removeUndefinedValues: true }),
    }));
  } catch (err) {
    console.error('[LOGGER ERROR] Gagal menulis API request log:', err.message);
  }
}

module.exports = { log, logApiRequest, calculateTTL };
