/* SPDX-License-Identifier: MPL-2.0
 * Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
 *
 * Generated C header for dicta-task FFI bridge.
 * DO NOT EDIT — regenerate from Idris2 ABI + Zig FFI.
 */

#ifndef DICTA_TASK_FFI_H
#define DICTA_TASK_FFI_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Task status enumeration */
typedef enum {
    DICTA_TASK_STATUS_PENDING = 0,
    DICTA_TASK_STATUS_IN_PROGRESS = 1,
    DICTA_TASK_STATUS_DONE = 2,
    DICTA_TASK_STATUS_REVIEW_NEEDED = 3,
    DICTA_TASK_STATUS_CANCELLED = 4,
} dicta_task_task_status_t;

/* Review state enumeration */
typedef enum {
    DICTA_TASK_REVIEW_PENDING = 0,
    DICTA_TASK_REVIEW_APPROVED = 1,
    DICTA_TASK_REVIEW_REJECTED = 2,
} dicta_task_review_state_t;

/* Intent type enumeration */
typedef enum {
    DICTA_TASK_INTENT_ADD_TASK = 0,
    DICTA_TASK_INTENT_UPDATE_TASK = 1,
    DICTA_TASK_INTENT_DELETE_TASK = 2,
    DICTA_TASK_INTENT_SET_DEADLINE = 3,
    DICTA_TASK_INTENT_SET_PRIORITY = 4,
    DICTA_TASK_INTENT_ADD_TAG = 5,
    DICTA_TASK_INTENT_NOTE = 6,
} dicta_task_intent_type_t;

/* C-compatible task struct */
typedef struct {
    uint8_t id[36];              /* UUID string */
    const uint8_t *title_ptr;
    size_t title_len;
    const uint8_t *description_ptr;  /* NULL if no description */
    size_t description_len;
    dicta_task_task_status_t status;
    double priority_urgency;
    double priority_importance;
    double priority_deadline_proximity;
    const uint8_t *due_date_ptr;     /* ISO 8601, NULL if none */
    size_t due_date_len;
    bool due_date_tentative;
    dicta_task_review_state_t review_state;
    double confidence;
} dicta_task_task_t;

/* C-compatible candidate intent struct */
typedef struct {
    uint8_t id[36];
    uint8_t transcript_id[36];
    const uint8_t *parser_version_ptr;
    size_t parser_version_len;
    dicta_task_intent_type_t intent_type;
    const uint8_t *raw_text_ptr;
    size_t raw_text_len;
    double confidence;
    bool review_required;
} dicta_task_candidate_intent_t;

/* Confidence functions */
double dicta_task_confidence_new(double value);
bool dicta_task_confidence_is_high(double value);
bool dicta_task_confidence_is_medium(double value);
bool dicta_task_confidence_is_low(double value);

/* Priority computation */
double dicta_task_priority_compute(double urgency, double importance, double deadline_proximity);

#ifdef __cplusplus
}
#endif

#endif /* DICTA_TASK_FFI_H */
