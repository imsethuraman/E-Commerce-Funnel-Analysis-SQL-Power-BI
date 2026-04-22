use funnel_db;

SELECT 
    COUNT(*),
    COUNT(DISTINCT `User ID`) AS total_users    
FROM funnel_data;

SELECT * FROM funnel_data limit 10;

SELECT `Product Category`, COUNT(DISTINCT `User ID`) AS users
FROM funnel_data
GROUP by `Product Category`;

-- Check nulls
SELECT 
    COUNT(*) AS total_rows,
	sum(`Event Time` is null) as `Event Time`, 
    sum(`Event` is null) as `Event`, 
    sum(`Device` is null) as Device,
    sum(`Region` is null) as Region,
    sum(`Channel` is null) as `Channel`, 
    sum(`Product Category` is null) as `Product Category`, 
    sum(`Revenue` is null) as Revenue, 
    sum(`Bonus Flag` is null) as `Bonus Flag`,
    SUM(`User ID` IS NULL) AS `User ID`,
    SUM( `Session ID` IS NULL) AS  `Session ID`
    FROM funnel_data;
    
SELECT event, COUNT(*) AS event_count
FROM funnel_data
GROUP BY event
ORDER BY event_count DESC;    

SELECT 
    COUNT(DISTINCT CASE WHEN event = 'Browse' THEN `User ID` END) AS browse_users,
    COUNT(DISTINCT CASE WHEN event = 'Add to Cart' THEN `User ID` END) AS cart_users,
    COUNT(DISTINCT CASE WHEN event = 'Checkout' THEN `User ID` END) AS checkout_users,
    COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN `User ID` END) AS buyers
FROM funnel_data;

-- Conversion Rates
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
    
    ROUND(cart/browse * 100,2) AS browse_to_cart,
    ROUND(checkout/cart * 100,2) AS cart_to_checkout,
    ROUND(purchase/checkout * 100,2) AS checkout_to_purchase
FROM funnel;

SELECT 
    `User ID`,
	MAX(event = 'Browse') AS browsed,
    MAX(event = 'Add to Cart') AS added_to_cart,
    MAX(event = 'Checkout') AS checkout_done,
    MAX(event = 'Purchase') AS purchased
FROM funnel_data
GROUP BY `User ID`;

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

SELECT round(SUM(revenue),2) AS total_revenue
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

SELECT 
    channel,
    COUNT(DISTINCT CASE WHEN event = 'Browse' THEN `User ID` END) AS browse,
    COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN `User ID` END) AS buyers,
    
    ROUND(
        COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN `User ID` END) /
        COUNT(DISTINCT CASE WHEN event = 'Browse' THEN `User ID` END) * 100, 2
    ) AS conversion_rate
FROM funnel_data
GROUP BY channel
ORDER BY conversion_rate DESC;

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


SELECT 
    `Product Category`,
    COUNT(DISTINCT `User ID`) AS users,
    SUM(revenue) AS revenue
FROM funnel_data
WHERE event = 'Purchase'
GROUP BY `Product Category`
ORDER BY revenue DESC;

SELECT 
    `User ID`,

    MIN(CASE WHEN event = 'Browse' THEN `Event Time` END) AS browse_time,

    MIN(CASE WHEN event = 'Purchase' THEN `Event Time` END) AS purchase_time,

    ROUND(
        TIME_TO_SEC(
            TIMEDIFF(
                MIN(CASE WHEN event = 'Purchase' THEN `Event Time` END),
                MIN(CASE WHEN event = 'Browse' THEN `Event Time` END)
            )
        ) / 60, 2
    ) AS browse_to_purchase_minutes,

    CASE 
        WHEN TIME_TO_SEC(
            TIMEDIFF(
                MIN(CASE WHEN event = 'Purchase' THEN `Event Time` END),
                MIN(CASE WHEN event = 'Browse' THEN `Event Time` END)
            )
        ) / 60 < 10 THEN 'Fast Converter'

        WHEN TIME_TO_SEC(
            TIMEDIFF(
                MIN(CASE WHEN event = 'Purchase' THEN `Event Time` END),
                MIN(CASE WHEN event = 'Browse' THEN `Event Time` END)
            )
        ) / 60 < 15 THEN 'Medium Converter'

        ELSE 'Slow Converter'
    END AS user_segment

FROM funnel_data
GROUP BY `User ID`
HAVING purchase_time IS NOT NULL;

SELECT 
    `User ID`,
    `Channel`,
    `Device`,
    `Region`
FROM funnel_data
GROUP BY `User ID`, `Channel`, `Device`, `Region`
HAVING 
    MAX(event = 'Checkout') = 1
    AND MAX(event = 'Purchase') = 0;
	
    WITH base AS (
    SELECT 
        `User ID`,
        channel,
        device,
        region,

        MIN(CASE WHEN event = 'Browse' THEN `Event Time` END) AS browse_time,
        MIN(CASE WHEN event = 'Purchase' THEN `Event Time` END) AS purchase_time,

        SUM(CASE WHEN event = 'Purchase' THEN revenue ELSE 0 END) AS revenue,

        TIME_TO_SEC(
            TIMEDIFF(
                MIN(CASE WHEN event = 'Purchase' THEN `Event Time` END),
                MIN(CASE WHEN event = 'Browse' THEN `Event Time` END)
            )
        ) / 60 AS minutes_diff

    FROM funnel_data
    GROUP BY `User ID`, channel, device, region
    HAVING purchase_time IS NOT NULL
),

segmented AS (
    SELECT *,
        CASE 
            WHEN minutes_diff < 5 THEN 'Fast Converter'
            WHEN minutes_diff < 15 THEN 'Medium Converter'
            ELSE 'Slow Converter'
        END AS user_segment
    FROM base
)

SELECT 
    channel,
    device,
    region,
    user_segment,

    COUNT(*) AS users,
    SUM(revenue) AS total_revenue,
    ROUND(AVG(revenue),2) AS avg_revenue_per_user

FROM segmented
GROUP BY channel, device, region, user_segment
ORDER BY total_revenue DESC;
    
    
    SELECT 
    user_segment,
    SUM(revenue) AS total_revenue
FROM segmented
GROUP BY user_segment
ORDER BY total_revenue DESC;

