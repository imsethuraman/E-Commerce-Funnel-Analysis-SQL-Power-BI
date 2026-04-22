-- =====================================================
-- E-COMMERCE FUNNEL & CUSTOMER ANALYSIS
-- =====================================================
-- Objective:
-- Analyze user funnel behavior, conversion, revenue drivers,
-- and customer segmentation to generate business insights.
-- =====================================================

USE funnel_db;

-- =====================================================
-- 1. DATA PREVIEW
-- =====================================================

SELECT * FROM funnel_data LIMIT 10;

-- =====================================================
-- 2. DATA OVERVIEW
-- =====================================================

SELECT 
    COUNT(*) AS total_events,
    COUNT(DISTINCT `User ID`) AS total_users    
FROM funnel_data;

-- =====================================================
-- 3. DATA QUALITY CHECK
-- =====================================================

SELECT 
    COUNT(*) AS total_rows,
    SUM(`Event Time` IS NULL) AS missing_event_time,
    SUM(`Event` IS NULL) AS missing_event,
    SUM(`Device` IS NULL) AS missing_device,
    SUM(`Region` IS NULL) AS missing_region,
    SUM(`Channel` IS NULL) AS missing_channel,
    SUM(`Product Category` IS NULL) AS missing_category,
    SUM(`Revenue` IS NULL) AS missing_revenue
FROM funnel_data;

-- =====================================================
-- 4. FUNNEL ANALYSIS
-- =====================================================

SELECT 
    COUNT(DISTINCT CASE WHEN event = 'Browse' THEN `User ID` END) AS browse_users,
    COUNT(DISTINCT CASE WHEN event = 'Add to Cart' THEN `User ID` END) AS cart_users,
    COUNT(DISTINCT CASE WHEN event = 'Checkout' THEN `User ID` END) AS checkout_users,
    COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN `User ID` END) AS buyers
FROM funnel_data;

-- =====================================================
-- 5. CONVERSION RATES
-- =====================================================

WITH funnel AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN event = 'Browse' THEN `User ID` END) AS browse,
        COUNT(DISTINCT CASE WHEN event = 'Add to Cart' THEN `User ID` END) AS cart,
        COUNT(DISTINCT CASE WHEN event = 'Checkout' THEN `User ID` END) AS checkout,
        COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN `User ID` END) AS purchase
    FROM funnel_data
)
SELECT 
    browse,
    cart,
    checkout,
    purchase,
    ROUND(cart/browse * 100,2) AS browse_to_cart_conversion,
    ROUND(checkout/cart * 100,2) AS cart_to_checkout_conversion,
    ROUND(purchase/checkout * 100,2) AS checkout_to_purchase_conversion
FROM funnel;

-- =====================================================
-- 6. DROP-OFF ANALYSIS
-- =====================================================

SELECT 
    COUNT(*) AS total_users,
    SUM(browsed = 1 AND added_to_cart = 0) AS drop_after_browse,
    SUM(added_to_cart = 1 AND checkout_done = 0) AS drop_after_cart,
    SUM(checkout_done = 1 AND purchased = 0) AS drop_after_checkout
FROM (
    SELECT 
        `User ID`,
        MAX(event = 'Browse') AS browsed,
        MAX(event = 'Add to Cart') AS added_to_cart,
        MAX(event = 'Checkout') AS checkout_done,
        MAX(event = 'Purchase') AS purchased
    FROM funnel_data
    GROUP BY `User ID`
) t;

-- =====================================================
-- 7. REVENUE ANALYSIS
-- =====================================================

SELECT ROUND(SUM(revenue),2) AS total_revenue
FROM funnel_data
WHERE event = 'Purchase';

SELECT 
    channel,
    COUNT(DISTINCT `User ID`) AS users,
    ROUND(SUM(revenue),2) AS revenue,
    ROUND(SUM(revenue)/COUNT(DISTINCT `User ID`),2) AS revenue_per_user
FROM funnel_data
WHERE event = 'Purchase'
GROUP BY channel
ORDER BY revenue DESC;

-- =====================================================
-- 8. DEVICE & REGION ANALYSIS
-- =====================================================

SELECT 
    device,
    COUNT(DISTINCT `User ID`) AS users,
    SUM(revenue) AS revenue,
    ROUND(SUM(revenue)/COUNT(DISTINCT `User ID`),2) AS avg_revenue
FROM funnel_data
GROUP BY device
ORDER BY revenue DESC;

SELECT 
    region,
    COUNT(DISTINCT `User ID`) AS users,
    SUM(revenue) AS revenue,
    ROUND(SUM(revenue)/COUNT(DISTINCT `User ID`),2) AS avg_revenue
FROM funnel_data
GROUP BY region
ORDER BY revenue DESC;

-- =====================================================
-- 9. CREATE TEMP TABLE (KEY STEP)
-- =====================================================

DROP TEMPORARY TABLE IF EXISTS segmented;

CREATE TEMPORARY TABLE segmented AS
SELECT 
    `User ID`,
    channel,
    device,
    region,

    -- Revenue per user
    SUM(CASE WHEN event = 'Purchase' THEN revenue ELSE 0 END) AS revenue,

    -- Conversion time (minutes)
    TIME_TO_SEC(
        TIMEDIFF(
            MIN(CASE WHEN event = 'Purchase' THEN `Event Time` END),
            MIN(CASE WHEN event = 'Browse' THEN `Event Time` END)
        )
    ) / 60 AS minutes_diff,

    -- Segmentation
    CASE 
        WHEN TIME_TO_SEC(
            TIMEDIFF(
                MIN(CASE WHEN event = 'Purchase' THEN `Event Time` END),
                MIN(CASE WHEN event = 'Browse' THEN `Event Time` END)
            )
        ) / 60 < 5 THEN 'Fast Converter'
        WHEN TIME_TO_SEC(
            TIMEDIFF(
                MIN(CASE WHEN event = 'Purchase' THEN `Event Time` END),
                MIN(CASE WHEN event = 'Browse' THEN `Event Time` END)
            )
        ) / 60 < 15 THEN 'Medium Converter'
        ELSE 'Slow Converter'
    END AS user_segment

FROM funnel_data
GROUP BY `User ID`, channel, device, region
HAVING revenue > 0;

-- =====================================================
-- 10. SEGMENT PERFORMANCE
-- =====================================================

SELECT 
    channel,
    device,
    region,
    user_segment,
    COUNT(*) AS users,
    SUM(revenue) AS total_revenue,
    ROUND(AVG(revenue),2) AS avg_revenue
FROM segmented
GROUP BY channel, device, region, user_segment
ORDER BY total_revenue DESC;

-- =====================================================
-- 11. TOP REVENUE SEGMENT
-- =====================================================

SELECT 
    user_segment,
    SUM(revenue) AS total_revenue
FROM segmented
GROUP BY user_segment
ORDER BY total_revenue DESC;