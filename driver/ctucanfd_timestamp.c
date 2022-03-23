// SPDX-License-Identifier: GPL-2.0-or-later
/*******************************************************************************
 *
 * CTU CAN FD IP Core
 *
 * Copyright (C) 2022 Matej Vasilevski <matej.vasilevski@seznam.cz> FEE CTU
 * 
 * Project advisors:
 *     Jiri Novak <jnovak@fel.cvut.cz>
 *     Pavel Pisa <pisa@cmp.felk.cvut.cz>
 *
 * Department of Measurement         (http://meas.fel.cvut.cz/)
 * Faculty of Electrical Engineering (http://www.fel.cvut.cz)
 * Czech Technical University        (http://www.cvut.cz/)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 ******************************************************************************/


#include <linux/clocksource.h>
#include <linux/math64.h>
#include <linux/timecounter.h>
#include "linux/timekeeping.h"
#include <linux/workqueue.h>

#include "ctucanfd.h"
#include "ctucanfd_kregs.h"

#define CTUCANFD_MAX_WORK_DELAY_SEC 3600

static u64 ctucan_timestamp_read(const struct cyclecounter *cc)
{
	struct ctucan_priv *priv;
	priv = container_of(cc, struct ctucan_priv, cc);
	return ctucan_read_timestamp_counter(priv);
}

static void ctucan_timestamp_work(struct work_struct *work)
{
	struct delayed_work *delayed_work = to_delayed_work(work);
	struct ctucan_priv *priv;
	priv = container_of(delayed_work, struct ctucan_priv, timestamp);

	timecounter_read(&priv->tc);

	schedule_delayed_work(&priv->timestamp, priv->work_delay_sec * HZ);
}

void ctucan_skb_set_timestamp(struct ctucan_priv *priv, struct sk_buff *skb, u64 timestamp) {
    u64 ns;
	struct skb_shared_hwtstamps *hwtstamps = skb_hwtstamps(skb);
	memset(hwtstamps, 0, sizeof(*hwtstamps));

	ns = timecounter_cyc2time(&priv->tc, timestamp);
	hwtstamps->hwtstamp = ns_to_ktime(ns);
}

static void setup_work_delay_constant(struct ctucan_priv *priv) {
	if (priv->timestamp_bit_size >= 64) {
		priv->work_delay_sec = CTUCANFD_MAX_WORK_DELAY_SEC;	
	}
	else {
		priv->work_delay_sec = div_u64(1LL << priv->timestamp_bit_size, priv->timestamp_freq);
		if (priv->work_delay_sec > CTUCANFD_MAX_WORK_DELAY_SEC) {
			priv->work_delay_sec = CTUCANFD_MAX_WORK_DELAY_SEC;
		}
	}
}

void ctucan_timestamp_init(struct ctucan_priv *priv)
{
	struct cyclecounter *cc = &priv->cc;

	cc->read = ctucan_timestamp_read;
	cc->mask = CYCLECOUNTER_MASK(priv->timestamp_bit_size);
	cc->shift = 0;
	cc->mult = clocksource_hz2mult(priv->timestamp_freq, cc->shift);

	timecounter_init(&priv->tc, &priv->cc, ktime_get_real_ns());

	setup_work_delay_constant(priv);
	INIT_DELAYED_WORK(&priv->timestamp, ctucan_timestamp_work);
	schedule_delayed_work(&priv->timestamp, priv->work_delay_sec * HZ);
}

void ctucan_timestamp_stop(struct ctucan_priv *priv)
{
	cancel_delayed_work_sync(&priv->timestamp);
}
