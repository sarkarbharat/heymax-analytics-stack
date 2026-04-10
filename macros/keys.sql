{% macro generate_surrogate_key(column_expressions) -%}
{%- if target.type in ['bigquery'] -%}
to_hex(md5(concat(
    {%- for col in column_expressions -%}
    coalesce(cast({{ col }} as string), '')
    {%- if not loop.last -%}, '|', {%- endif -%}
    {%- endfor -%}
)))
{%- else -%}
md5(concat(
    {%- for col in column_expressions -%}
    coalesce(cast({{ col }} as string), '')
    {%- if not loop.last -%}, '|', {%- endif -%}
    {%- endfor -%}
))
{%- endif -%}
{%- endmacro %}

{% macro generate_user_sk(user_id_expression) -%}
{{ generate_surrogate_key([user_id_expression]) }}
{%- endmacro %}
