// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
//! dictask store: SQLite canonical task store and view generation.
//!
//! This is the single source of truth for all tasks. All reads and writes
//! go through this module. Views (Markdown, JSON, CSV) are generated from
//! the canonical store.

use anyhow::Result;
use rusqlite::Connection;
use std::path::Path;

/// Initialise the SQLite database from the schema file.
pub fn init_db(db_path: &Path, schema_path: &Path) -> Result<Connection> {
    let conn = Connection::open(db_path)?;

    // Enable WAL mode for concurrent reads
    conn.execute_batch("PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;")?;

    // Run schema if tables don't exist
    let schema = std::fs::read_to_string(schema_path)?;
    conn.execute_batch(&schema)?;

    Ok(conn)
}

/// Generate a Markdown view of all pending/active tasks.
pub fn generate_markdown_view(conn: &Connection) -> Result<String> {
    let mut stmt = conn.prepare(
        "SELECT id, title, status, priority_score, due_date, project, review_state
         FROM tasks
         WHERE status NOT IN ('done', 'cancelled')
         ORDER BY priority_score DESC"
    )?;

    let mut output = String::from("# dictask — Active Tasks\n\n");
    output.push_str("| Priority | Title | Status | Due Date | Project | Review |\n");
    output.push_str("|----------|-------|--------|----------|---------|--------|\n");

    let rows = stmt.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,      // id
            row.get::<_, String>(1)?,      // title
            row.get::<_, String>(2)?,      // status
            row.get::<_, f64>(3)?,         // priority_score
            row.get::<_, Option<String>>(4)?, // due_date
            row.get::<_, Option<String>>(5)?, // project
            row.get::<_, String>(6)?,      // review_state
        ))
    })?;

    for row in rows {
        let (_, title, status, priority, due_date, project, review) = row?;
        let due = due_date.unwrap_or_else(|| "—".to_string());
        let proj = project.unwrap_or_else(|| "—".to_string());
        output.push_str(&format!(
            "| {:.2} | {} | {} | {} | {} | {} |\n",
            priority, title, status, due, proj, review
        ));
    }

    Ok(output)
}

/// Generate a JSON view of all tasks.
pub fn generate_json_view(conn: &Connection) -> Result<String> {
    let mut stmt = conn.prepare(
        "SELECT id, title, description, status, priority_score, urgency, importance,
                due_date, due_date_tentative, tags_json, project, review_state,
                created_at, updated_at
         FROM tasks
         ORDER BY priority_score DESC"
    )?;

    let rows = stmt.query_map([], |row| {
        Ok(serde_json::json!({
            "id": row.get::<_, String>(0)?,
            "title": row.get::<_, String>(1)?,
            "description": row.get::<_, Option<String>>(2)?,
            "status": row.get::<_, String>(3)?,
            "priority_score": row.get::<_, f64>(4)?,
            "urgency": row.get::<_, f64>(5)?,
            "importance": row.get::<_, f64>(6)?,
            "due_date": row.get::<_, Option<String>>(7)?,
            "due_date_tentative": row.get::<_, bool>(8)?,
            "tags": row.get::<_, String>(9)?,
            "project": row.get::<_, Option<String>>(10)?,
            "review_state": row.get::<_, String>(11)?,
            "created_at": row.get::<_, String>(12)?,
            "updated_at": row.get::<_, String>(13)?,
        }))
    })?;

    let tasks: Vec<serde_json::Value> = rows.filter_map(|r| r.ok()).collect();
    Ok(serde_json::to_string_pretty(&tasks)?)
}
