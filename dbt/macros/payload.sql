{% macro payload_text(key) -%}
nullif(trim(payload ->> '{{ key }}'), '')
{%- endmacro %}

{% macro ten_thousand_won_to_won(key) -%}
(replace({{ payload_text(key) }}, ',', '')::BIGINT * 10000)
{%- endmacro %}

{% macro lot_number(key, part) -%}
CASE
    WHEN {{ payload_text(key) }} ~ '^[0-9]+(-[0-9]+)?$'
        THEN coalesce(nullif(split_part({{ payload_text(key) }}, '-', {{ part }}), ''), '0')::INT
END
{%- endmacro %}
