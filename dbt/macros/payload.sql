{% macro payload_text(key) -%}
nullif(trim(payload ->> '{{ key }}'), '')
{%- endmacro %}

{% macro ten_thousand_won_to_won(key) -%}
(replace({{ payload_text(key) }}, ',', '')::bigint * 10000)
{%- endmacro %}

{% macro lot_number(key, part) -%}
case
    when {{ payload_text(key) }} ~ '^[0-9]+(-[0-9]+)?$'
        then coalesce(nullif(split_part({{ payload_text(key) }}, '-', {{ part }}), ''), '0')::int
end
{%- endmacro %}
