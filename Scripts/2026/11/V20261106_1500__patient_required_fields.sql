-- ============================================================================
-- Cadastro de pacientes: campos obrigatorios configuraveis.
--
-- Nome completo, data de nascimento e CPF passam a ser sempre obrigatorios
-- (regra em ad.patient_save). Os demais campos podem ser marcados como
-- obrigatorios pela filial:
--
--   od.branch_setting  + vc_patient_required  lista de campos obrigatorios:
--                          rg, gender, marital_status, education, source,
--                          referral, mobile, phone, email, address,
--                          profession, plan
--                      - id_require_cpf       (CPF agora e sempre obrigatorio)
--                      - id_require_mobile    (vira 'mobile' na lista)
--
-- Leitura por RLS (ja existente); escrita so por ad.settings_save.
-- ============================================================================

alter table od.branch_setting add column vc_patient_required text[] not null default '{}';
alter table od.branch_setting add constraint branch_setting_patient_required_check
  check (vc_patient_required <@ '{rg,gender,marital_status,education,source,referral,mobile,phone,email,address,profession,plan}'::text[]);

update od.branch_setting set vc_patient_required = '{mobile}' where id_require_mobile;

alter table od.branch_setting drop column id_require_cpf;
alter table od.branch_setting drop column id_require_mobile;
