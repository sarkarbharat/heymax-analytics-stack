{% macro generate_surrogate_key(column_expressions) -%}
to_hex(md5(concat(
    {%- for col in column_expressions -%}
    coalesce(cast({{ col }} as string), '')
    {%- if not loop.last -%}, '|', {%- endif -%}
    {%- endfor -%}
)))
{%- endmacro %}

{% macro generate_user_sk(user_id_expression) -%}
{{ generate_surrogate_key([user_id_expression]) }}
{%- endmacro %}
