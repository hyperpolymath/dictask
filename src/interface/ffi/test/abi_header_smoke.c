/* SPDX-License-Identifier: MPL-2.0
 * Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
 *
 * Compile-only consumer test for the generated C ABI.
 */

#include "../../generated/dicta_task_ffi.h"

_Static_assert(DICTA_TASK_STATUS_PENDING == 0, "task status ABI changed");
_Static_assert(DICTA_TASK_STATUS_CANCELLED == 4, "task status ABI changed");
_Static_assert(DICTA_TASK_REVIEW_PENDING == 0, "review state ABI changed");
_Static_assert(DICTA_TASK_REVIEW_REJECTED == 2, "review state ABI changed");
_Static_assert(DICTA_TASK_INTENT_ADD_TASK == 0, "intent type ABI changed");
_Static_assert(DICTA_TASK_INTENT_NOTE == 6, "intent type ABI changed");

double dicta_task_ffi_header_smoke_test(double confidence)
{
    const double bounded = dicta_task_confidence_new(confidence);

    if (dicta_task_confidence_is_high(bounded) ||
        dicta_task_confidence_is_medium(bounded) ||
        dicta_task_confidence_is_low(bounded)) {
        return dicta_task_priority_compute(bounded, bounded, bounded);
    }

    return 0.0;
}
