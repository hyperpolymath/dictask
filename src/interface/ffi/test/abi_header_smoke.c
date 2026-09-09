/* SPDX-License-Identifier: MPL-2.0
 * Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
 *
 * Compile-only consumer test for the generated C ABI.
 */

#include "../../generated/dictask_ffi.h"

_Static_assert(DICTASK_STATUS_PENDING == 0, "task status ABI changed");
_Static_assert(DICTASK_STATUS_CANCELLED == 4, "task status ABI changed");
_Static_assert(DICTASK_REVIEW_PENDING == 0, "review state ABI changed");
_Static_assert(DICTASK_REVIEW_REJECTED == 2, "review state ABI changed");
_Static_assert(DICTASK_INTENT_ADD_TASK == 0, "intent type ABI changed");
_Static_assert(DICTASK_INTENT_NOTE == 6, "intent type ABI changed");

double dictask_ffi_header_smoke_test(double confidence)
{
    const double bounded = dictask_confidence_new(confidence);

    if (dictask_confidence_is_high(bounded) ||
        dictask_confidence_is_medium(bounded) ||
        dictask_confidence_is_low(bounded)) {
        return dictask_priority_compute(bounded, bounded, bounded);
    }

    return 0.0;
}
