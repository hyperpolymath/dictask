/* SPDX-License-Identifier: PMPL-1.0-or-later
 * Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
 *
 * Generated C header for dictask FFI bridge.
 * DO NOT EDIT — regenerate from Idris2 ABI + Zig FFI.
 */

#ifndef DICTASK_FFI_H
#define DICTASK_FFI_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Task status enumeration */
typedef enum {
    DICTASK_STATUS_PENDING = 0,
    DICTASK_STATUS_IN_PROGRESS = 1,
    DICTASK_STATUS_DONE = 2,
    DICTASK_STATUS_REVIEW_NEEDED = 3,
    DICTASK_STATUS_CANCELLED = 4,
} dictask_task_status_t;

/* Review state enumeration */
typedef enum {
    DICTASK_REVIEW_PENDING = 0,
    DICTASK_REVIEW_APPROVED = 1,
    DICTASK_REVIEW_REJECTED = 2,
} dictask_review_state_t;

/* Intent type enumeration */
typedef enum {
    DICTASK_INTENT_ADD_TASK = 0,
    DICTASK_INTENT_UPDATE_TASK = 1,
    DICTASK_INTENT_DELETE_TASK = 2,
    DICTASK_INTENT_SET_DEADLINE = 3,
    DICTASK_INTENT_SET_PRIORITY = 4,
    DICTASK_INTENT_ADD_TAG = 5,
    DICTASK_INTENT_NOTE = 6,
} dictask_intent_type_t;

/* C-compatible task struct */
typedef struct {
    uint8_t id[36];              /* UUID string */
    const uint8_t *title_ptr;
    size_t title_len;
    const uint8_t *description_ptr;  /* NULL if no description */
    size_t description_len;
    dictask_task_status_t status;
    double priority_urgency;
    double priority_importance;
    double priority_deadline_proximity;
    const uint8_t *due_date_ptr;     /* ISO 8601, NULL if none */
    size_t due_date_len;
    bool due_date_tentative;
    dictask_review_state_t review_state;
    double confidence;
} dictask_task_t;

/* C-compatible candidate intent struct */
typedef struct {
    uint8_t id[36];
    uint8_t transcript_id[36];
    const uint8_t *parser_version_ptr;
    size_t parser_version_len;
    dictask_intent_type_t intent_type;
    const uint8_t *raw_text_ptr;
    size_t raw_text_len;
    double confidence;
    bool review_required;
} dictask_candidate_intent_t;

/* Confidence functions */
double dictask_confidence_new(double value);
bool dictask_confidence_is_high(double value);
bool dictask_confidence_is_medium(double value);
bool dictask_confidence_is_low(double value);

/* Priority computation */
double dictask_priority_compute(double urgency, double importance, double deadline_proximity);

#ifdef __cplusplus
}
#endif

#endif /* DICTASK_FFI_H */
