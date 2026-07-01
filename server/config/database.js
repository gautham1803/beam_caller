const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  host: process.env.DATABASE_URL ? undefined : (process.env.DB_HOST || 'localhost'),
  port: process.env.DATABASE_URL ? undefined : parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DATABASE_URL ? undefined : (process.env.DB_NAME || 'caller_db'),
  user: process.env.DATABASE_URL ? undefined : (process.env.DB_USER || 'postgres'),
  password: process.env.DATABASE_URL ? undefined : (process.env.DB_PASSWORD || 'postgres'),
  ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

pool.on('error', (err) => {
  console.error('Unexpected database error:', err);
});

async function initDatabase() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        number VARCHAR(6) UNIQUE NOT NULL,
        device_id VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        push_token VARCHAR(255)
      );
    `);

    // Ensure column exists for existing tables
    await client.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS push_token VARCHAR(255);
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS active_connections (
        user_number VARCHAR(6) PRIMARY KEY REFERENCES users(number) ON DELETE CASCADE,
        socket_id VARCHAR(255) NOT NULL,
        last_ping TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS call_history (
        id SERIAL PRIMARY KEY,
        caller VARCHAR(6) NOT NULL,
        receiver VARCHAR(6) NOT NULL,
        type VARCHAR(10) NOT NULL DEFAULT 'voice',
        started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        ended_at TIMESTAMP WITH TIME ZONE,
        duration INTEGER DEFAULT 0
      );
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_users_number ON users(number);
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_users_device_id ON users(device_id);
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_active_connections_socket ON active_connections(socket_id);
    `);

    console.log('📦 Database tables ready');
  } finally {
    client.release();
  }
}

module.exports = { pool, initDatabase };
