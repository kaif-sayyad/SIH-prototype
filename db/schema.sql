-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(256) PRIMARY KEY,
  phone VARCHAR(32),
  email VARCHAR(128),
  role VARCHAR(32) NOT NULL DEFAULT 'family',
  consent BOOLEAN DEFAULT FALSE,
  consent_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
  id VARCHAR(256) PRIMARY KEY,
  user_id VARCHAR(256) REFERENCES users(id),
  student_profile JSONB DEFAULT '{}',
  family_context JSONB DEFAULT '{}',
  status VARCHAR(32) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Concerns table
CREATE TABLE IF NOT EXISTS concerns (
  id VARCHAR(256) PRIMARY KEY,
  session_id VARCHAR(256) REFERENCES sessions(id) ON DELETE CASCADE,
  category VARCHAR(64) NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'raised',
  asked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP,
  evidence_used JSONB DEFAULT '{}'
);

-- Outcomes table (structured data rows)
CREATE TABLE IF NOT EXISTS outcomes (
  id VARCHAR(256) PRIMARY KEY,
  trade VARCHAR(128) NOT NULL,
  location VARCHAR(128) NOT NULL,
  provider VARCHAR(256),
  placement_rate NUMERIC,
  avg_earnings NUMERIC,
  earnings_min NUMERIC,
  earnings_max NUMERIC,
  nsqf_level INT,
  duration_months INT,
  training_cost NUMERIC,
  min_education VARCHAR(64),
  job_roles JSONB DEFAULT '[]',
  progression JSONB DEFAULT '[]',
  further_education TEXT,
  source TEXT,
  data_date VARCHAR(32),
  dataset_version VARCHAR(128),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Outcome Chunks table (RAG fact documents with pgvector embeddings)
CREATE TABLE IF NOT EXISTS outcome_chunks (
  id VARCHAR(256) PRIMARY KEY,
  outcome_id VARCHAR(256) REFERENCES outcomes(id) ON DELETE CASCADE,
  topic VARCHAR(64) NOT NULL,
  text TEXT NOT NULL,
  trade VARCHAR(128) NOT NULL,
  location VARCHAR(128) NOT NULL,
  source TEXT,
  data_date VARCHAR(32),
  embedding vector(768)
);

-- Escalations table
CREATE TABLE IF NOT EXISTS escalations (
  id VARCHAR(256) PRIMARY KEY,
  session_id VARCHAR(256) REFERENCES sessions(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  status VARCHAR(32) DEFAULT 'open',
  counsellor_id VARCHAR(256) REFERENCES users(id),
  counsellor_notes TEXT,
  evidence_shown JSONB DEFAULT '[]',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Datasets table
CREATE TABLE IF NOT EXISTS datasets (
  id VARCHAR(256) PRIMARY KEY,
  version VARCHAR(128) NOT NULL UNIQUE,
  filename VARCHAR(256),
  total_rows INT DEFAULT 0,
  valid_rows INT DEFAULT 0,
  rejected_rows INT DEFAULT 0,
  uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Coverage Gaps table
CREATE TABLE IF NOT EXISTS coverage_gaps (
  id VARCHAR(256) PRIMARY KEY,
  trade VARCHAR(128),
  location VARCHAR(128),
  question TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
