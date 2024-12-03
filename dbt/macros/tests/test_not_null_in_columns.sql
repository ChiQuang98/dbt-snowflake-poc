{% test not_null_in_columns(model, column_names, row_condition) %}

SELECT 1
FROM {{ model }}
WHERE
    (
        {% for column in column_names %}
            {{ column }} IS NULL
            {% if not loop.last %}
                OR
            {% endif %}
        {% endfor %}
    )

    {% set test_depends_on_nodes = config.model.depends_on.nodes %}
    {% if test_depends_on_nodes | length != 1 %}
        {% if execute %}
            {{ log("Test: " + model.render(), info=True) }}
            {{ log('Expected test to have a single node dependency. If this is testing a snapshot object, all rows will be checked instead of only "valid" rows.', info=True) }}
            {{ log("Found node dependencies: ", info=True) }}
            {{ log(test_depends_on_nodes, info=True) }}
        {% endif %}
    {% elif graph.nodes[test_depends_on_nodes[0]].resource_type == 'snapshot' %}
        AND dbt_valid_to IS NULL
    {% endif %}

    {% if row_condition %}
        AND {{ row_condition }}
    {% endif %}

{% endtest %}
