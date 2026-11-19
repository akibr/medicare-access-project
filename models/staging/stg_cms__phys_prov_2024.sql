-- One row per NPI (same grain as raw).
-- Renames columns and sets types. No filtering here.
-- Totals include services suppressed in the provider-service file (CMS methodology 4.2).

with source as (

    select * from {{ source('cms', 'raw_phys_prov_2024') }}

),

renamed as (

    select
        -- provider
        Rndrng_NPI                          as npi,
        Rndrng_Prvdr_Ent_Cd                 as entity_code,      -- I = individual, O = organization
        Rndrng_Prvdr_Type                   as provider_type,

        -- totals across all claims
        cast(Tot_HCPCS_Cds as integer)      as total_hcpcs_codes,
        cast(Tot_Benes as integer)          as total_beneficiaries,
        cast(Tot_Srvcs as double)           as total_services,   -- can be fractional

        -- medical (non-drug) subtotal; NULL when CMS suppresses it
        Med_Sprsn_Ind                       as medical_suppression_flag,  -- * = under 11 benes, # = counter-suppressed
        cast(Med_Tot_Srvcs as double)       as medical_services

    from source

)

select * from renamed
