WITH total_revenue_by_users AS (
    SELECT 
        gp.user_id,
        DATE_TRUNC('month', gp.payment_date) AS payment_month,
        SUM(gp.revenue_amount_usd) AS total_revenue
    FROM project.games_payments gp
    GROUP BY 
        gp.user_id,
        DATE_TRUNC('month', gp.payment_date)
),

revenue_with_lags AS (
    SELECT 
        tr.user_id,
        tr.payment_month,
        tr.total_revenue,
        LAG(payment_month) OVER (PARTITION BY user_id ORDER BY payment_month) AS previous_paid_month,
        LEAD(payment_month) OVER (PARTITION BY user_id ORDER BY payment_month) AS next_paid_month,
        DATE(payment_month + INTERVAL '1 month') AS next_calendar_month,
        DATE(payment_month - INTERVAL '1 month') AS previous_calendar_month,
        LAG(total_revenue) OVER (PARTITION BY user_id ORDER BY payment_month) AS previous_paid_month_revenue
    FROM total_revenue_by_users tr
),

final_cte AS (
    SELECT 
        user_id,
        payment_month,
        total_revenue,
        previous_paid_month,
        next_paid_month,
        next_calendar_month,
        previous_calendar_month,
        previous_paid_month_revenue,
        CASE WHEN previous_paid_month IS NULL THEN total_revenue END AS new_MRR,
        CASE WHEN previous_paid_month IS NULL THEN 1 END AS new_paid_users,
        CASE WHEN next_paid_month IS NULL OR next_paid_month != next_calendar_month THEN total_revenue END AS churn_revenue,
        CASE WHEN next_paid_month IS NULL OR next_paid_month != next_calendar_month THEN 1 END AS churn_users,
        CASE WHEN next_paid_month IS NULL OR next_paid_month != next_calendar_month THEN next_calendar_month END AS churn_month,
        CASE WHEN previous_paid_month = previous_calendar_month AND total_revenue > previous_paid_month_revenue
             THEN total_revenue - previous_paid_month_revenue END AS expansion_revenue,
        CASE WHEN previous_paid_month = previous_calendar_month AND total_revenue < previous_paid_month_revenue
             THEN total_revenue - previous_paid_month_revenue END AS contraction_revenue
    FROM revenue_with_lags
)

SELECT *
FROM final_cte as fc
left join games_paid_users as gp 
on(fc.user_id=gp.user_id);