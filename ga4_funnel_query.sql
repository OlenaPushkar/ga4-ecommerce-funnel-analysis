WITH sessions_info AS (
  SELECT
    -- унікальний ідентифікатор сесії
    CONCAT(
      user_pseudo_id,
      CAST(
        (SELECT value.int_value
         FROM UNNEST(event_params)
         WHERE key = 'ga_session_id') AS STRING
      )
    ) AS user_session_id,

    user_pseudo_id,

    -- час старту сесії
    TIMESTAMP_MICROS(event_timestamp) AS session_start_time,

    -- landing page (шлях першої сторінки)
    REGEXP_EXTRACT(
      (SELECT ep.value.string_value
       FROM UNNEST(event_params) ep
       WHERE ep.key = 'page_location'),
      r'^https?:\/\/[^\/]+\/([^\/]+)'
    ) AS landing_page_location,

    -- атрибути сесії на момент session_start
    geo.country AS country,
    device.category AS device_category,
    device.language AS device_language,
    device.operating_system AS device_operating_system,
    traffic_source.source AS source,
    traffic_source.medium AS medium,
    traffic_source.name AS campaign

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'session_start'
),

events AS (
  SELECT
    CONCAT(
      user_pseudo_id,
      CAST(
        (SELECT value.int_value
         FROM UNNEST(event_params)
         WHERE key = 'ga_session_id') AS STRING
      )
    ) AS user_session_id,

    event_name,
    TIMESTAMP_MICROS(event_timestamp) AS event_timestamp

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name IN (
    'session_start',
    'view_item',
    'add_to_cart',
    'begin_checkout',
    'add_shipping_info',
    'add_payment_info',
    'purchase'
  )
)

SELECT
  s.session_start_time,
  s.landing_page_location,
  s.country,
  s.source,
  s.medium,
  s.campaign,
  s.device_category,
  s.device_language,
  s.device_operating_system,

  e.event_name,
  e.event_timestamp,

  -- для воронки в Tableau
  COUNT(DISTINCT s.user_session_id) AS sessions

FROM sessions_info s
LEFT JOIN events e
USING (user_session_id)

GROUP BY
  1,2,3,4,5,6,7,8,9,10,11

ORDER BY
  session_start_time, event_timestamp;
