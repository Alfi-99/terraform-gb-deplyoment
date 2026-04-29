/**
 * Response Helper Utility
 * Standardisasi response format untuk API Gateway
 */

/**
 * Buat response sukses
 * @param {object|array} data - Data yang dikembalikan
 * @param {number} statusCode - HTTP status code
 * @param {string} message - Pesan sukses
 */
function success(data, statusCode = 200, message = 'Success') {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
      'X-Request-Id': process.env.AWS_REQUEST_ID || '',
    },
    body: JSON.stringify({
      success: true,
      message,
      data,
      timestamp: new Date().toISOString(),
    }),
  };
}

/**
 * Buat response error
 * @param {string} message - Pesan error
 * @param {number} statusCode - HTTP status code
 * @param {object} details - Detail error
 */
function error(message, statusCode = 500, details = null) {
  const body = {
    success: false,
    message,
    timestamp: new Date().toISOString(),
  };

  if (details && process.env.NODE_ENV !== 'prod') {
    body.details = details;
  }

  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    },
    body: JSON.stringify(body),
  };
}

/**
 * Response untuk CORS preflight
 */
function cors() {
  return {
    statusCode: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    },
    body: '',
  };
}

module.exports = { success, error, cors };
