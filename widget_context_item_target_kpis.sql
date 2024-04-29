CREATE OR REPLACE VIEW widget_context_item_target_kpis AS
SELECT
  t.widget,
  STRUCT(
    t.target_product_id AS product_id,
    t.target_title_de AS title_de,
    spps.gender,
    spps.category,
    spps.price,
    tpiat.products_group_id,
    tpiat.image_de AS image,
    tpiat.link_de AS link 
  ) AS target_product,
  t.kpis
FROM (
  SELECT
    widget,
    target_product_id,
    ANY_VALUE(target_title_de) AS target_title_de,
    STRUCT(
      SUM(KPI_defined.clicks) AS clicks,
      SUM(KPI_defined.mainImpressions) AS mainImpressions,
      SUM(KPI_defined.click_n_buys) AS click_n_buys,
      SUM(KPI_defined.click_n_revenue) AS click_n_revenue,
      IF(SUM(KPI_defined.mainImpressions) > 0, SUM(KPI_defined.clicks) / SUM(KPI_defined.mainImpressions), 0) AS CTR,
      IF(SUM(KPI_defined.mainImpressions) > 0, SUM(KPI_defined.click_n_buys) / SUM(KPI_defined.mainImpressions), 0) AS BTR,
      IF(SUM(KPI_defined.clicks) > 0, SUM(KPI_defined.click_n_buys) / SUM(KPI_defined.clicks), 0) AS Conversion_rate
    ) AS kpis
  FROM
    product-recommendation-421809.product_data.widget_context_item_product
  GROUP BY
    target_product_id,
    widget
) AS t
LEFT JOIN (
  SELECT
    product_id,
    MAX((SELECT property_values[SAFE_OFFSET(0)] FROM UNNEST(product_properties) AS property WHERE property.property_name = 'Gender_de')) AS gender,
    MAX(CAST((SELECT property_values[SAFE_OFFSET(0)] FROM UNNEST(product_properties) AS property WHERE property.property_name = 'discountedPrice') AS FLOAT64)) AS price,
    MAX(product_id_properties.categories_de_3[SAFE_OFFSET(0)]) AS category
  FROM
    product-recommendation-421809.product_data.product_property_structures  
  GROUP BY
    product_id
) spps ON t.target_product_id = spps.product_id
LEFT JOIN product-recommendation-421809.product_data.product_image_and_title
  ON t.target_product_id = tpiat.product_id;
