CREATE OR REPLACE TABLE widget_context_item_source_target_kpis AS
WITH wci AS (
  SELECT
    IFNULL(p.products_group_id, t.source_product_id) AS source_product_id,
    ANY_VALUE(t.source_title_de) AS source_title_de,
    t.target_product_id,
    t.widget,
    ANY_VALUE(t.target_title_de) AS target_title_de,
    SUM(t.KPI_defined.clicks) AS clicks,
    SUM(t.KPI_defined.mainImpressions) AS mainImpressions,
    SUM(t.KPI_defined.click_n_buys) AS click_n_buys,
    SUM(t.KPI_defined.click_n_revenue) AS click_n_revenue
  FROM
    product-recommendation-421809.product_data.widget_context_item_product AS t
  LEFT JOIN product-recommendation-421809.product_data.product_image_and_title AS p 
    ON t.source_product_id = p.product_id
  GROUP BY
    source_product_id,
    target_product_id,
    widget 
),

prod_info AS (
  SELECT
    product_id,
    MAX((SELECT property_values[SAFE_OFFSET(0)] FROM UNNEST(product_properties) AS property WHERE property.property_name = 'Gender_de' LIMIT 1)) AS gender,
    MAX(CAST((SELECT property_values[SAFE_OFFSET(0)] FROM UNNEST(product_properties) AS property WHERE property.property_name = 'discountedPrice' LIMIT 1) AS FLOAT64)) AS price,
    MAX(product_id_properties.categories_de_3[SAFE_OFFSET(0)]) AS category
  FROM
    product-recommendation-421809.product_data.product_property_structures
  GROUP BY
    product_id
)

SELECT
  wci.widget,
  STRUCT( 
    wci.source_product_id AS product_id,
    wci.source_title_de AS title_de,
    spps.gender,
    spps.category,
    spps.price,
    spit.products_group_id,
    spit.image_de AS image,
    spit.link_de AS link 
  ) AS source_product,
  STRUCT( 
    wci.target_product_id AS product_id,
    wci.target_title_de AS title_de,
    tpps.gender,
    tpps.category,
    tpps.price,
    t_pit.products_group_id,
    t_pit.image_de AS image,
    t_pit.link_de AS link 
  ) AS target_product,
  STRUCT( 
    clicks,
    mainImpressions,
    click_n_buys,
    click_n_revenue,
    IF(mainImpressions > 0, clicks / mainImpressions, 0) AS CTR,
    IF(mainImpressions > 0, click_n_buys / mainImpressions, 0) AS BTR,
    IF(clicks > 0, click_n_buys / clicks, 0) AS Conversion_rate
  ) AS kpis
FROM wci
LEFT JOIN prod_info spps ON wci.source_product_id = spps.product_id
LEFT JOIN prod_info tpps ON wci.target_product_id = tpps.product_id
LEFT JOIN product-recommendation-421809.product_data.product_image_and_title spit ON wci.source_product_id = spit.product_id
LEFT JOIN product-recommendation-421809.product_data.product_image_and_title t_pit ON wci.target_product_id = t_pit.product_id;
