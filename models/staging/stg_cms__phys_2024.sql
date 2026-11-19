-- One row per NPI, HCPCS code, and place of service (same grain as raw).
-- Renames columns and sets types. No filtering here.

with source as (

    select * from {{ source('cms', 'raw_phys_2024') }}

),

renamed as (

    select
        -- provider
        Rndrng_NPI                          as npi,  -- identifier, keep as text
        Rndrng_Prvdr_Last_Org_Name          as provider_last_or_org_name,
        Rndrng_Prvdr_First_Name             as provider_first_name,
        Rndrng_Prvdr_Crdntls                as provider_credentials,
        Rndrng_Prvdr_Ent_Cd                 as entity_code,  -- I = individual, O = organization
        Rndrng_Prvdr_State_Abrvtn           as provider_state,
        Rndrng_Prvdr_RUCA                   as ruca_code,
        Rndrng_Prvdr_Type                   as provider_type,  -- CMS specialty
        Rndrng_Prvdr_Mdcr_Prtcptg_Ind       as medicare_participating,

        -- service
        HCPCS_Cd                            as hcpcs_code,
        HCPCS_Desc                          as hcpcs_description,
        HCPCS_Drug_Ind                      as is_drug,
        Place_Of_Srvc                       as place_of_service,  -- F = facility, O = office

        -- volume
        cast(Tot_Benes as integer)          as total_beneficiaries,
        cast(Tot_Srvcs as double)           as total_services  -- can be fractional

    from source

)

select * from renamed
