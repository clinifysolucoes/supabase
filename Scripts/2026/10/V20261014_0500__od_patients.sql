-- ============================================================================
-- Pacientes (schema od): cadastro do paciente da filial e notas gerais.
--
-- Estrutura da ficha (inspirada nas fichas classicas de clinica):
--   dados cadastrais    nome, apelido, CPF, RG, nascimento, genero, estado civil,
--                       escolaridade, como conheceu, indicado por, observacoes
--   contato / endereco  celular, telefone fixo, outro telefone, contato pelo
--                       celular de, e-mail (ou "nao possui"), CEP, UF, cidade,
--                       endereco, numero, bairro, complemento
--   complementares      n. prontuario, profissao, local e tempo de trabalho,
--                       plano/convenio, filiacao (pai, mae) e representante legal
--   alerta de retorno   data + motivo (lembrar de chamar o paciente)
--   od.patient_note     notas gerais do prontuario (autor, data, texto)
--
-- Documentos, telefones e CEP sao guardados so com digitos (a mascara e do app).
-- CPF unico por filial (quando informado) e validado por ad.fn_cpf_is_valid.
-- Leitura por RLS (private.fn_my_branches, em rls_od_policies.pgs); escrita so
-- pelas RPCs ad.patient_save e ad.patient_note_save, que checam a permissao
-- na tela PATIENTS (ler / criar / alterar).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- od.patient - um paciente por filial (nr_patient sequencial por filial)
-- ---------------------------------------------------------------------------
create table od.patient (
  nr_company             bigint        not null,
  nr_branch              bigint        not null,
  nr_patient             bigint        not null,
  vc_name                varchar(120)  not null,
  vc_nickname            varchar(60),
  vc_cpf                 varchar(11),
  vc_rg                  varchar(20),
  dt_birth               date          not null,
  it_gender              smallint,
  it_marital_status      smallint,
  it_education           smallint,
  it_source              smallint,
  vc_referral            varchar(120),
  vc_notes               text,
  vc_phone               varchar(11),
  vc_mobile              varchar(11),
  vc_phone_other         varchar(11),
  vc_contact_name        varchar(80),
  vc_email               varchar(120),
  id_no_email            boolean       not null default false,
  vc_zip                 varchar(8),
  vc_state               varchar(2),
  vc_city                varchar(80),
  vc_address             varchar(120),
  vc_address_number      varchar(10),
  vc_district            varchar(80),
  vc_address_complement  varchar(60),
  vc_record_number       varchar(20),
  vc_profession          varchar(80),
  vc_workplace           varchar(80),
  vc_work_time           varchar(40),
  vc_plan_name           varchar(80),
  vc_plan_number         varchar(40),
  vc_father_name         varchar(120),
  vc_father_cpf          varchar(11),
  vc_father_rg           varchar(20),
  vc_father_profession   varchar(80),
  vc_mother_name         varchar(120),
  vc_mother_cpf          varchar(11),
  vc_mother_rg           varchar(20),
  vc_mother_profession   varchar(80),
  vc_guardian_name       varchar(120),
  vc_guardian_cpf        varchar(11),
  vc_guardian_rg         varchar(20),
  vc_guardian_phone      varchar(11),
  dt_return_alert        date,
  vc_return_alert        varchar(200),
  it_status              smallint      not null default 1,
  nr_operator            bigint,
  dh_created             timestamptz   not null default now(),
  dh_updated             timestamptz   not null default now(),
  constraint patient_pk primary key (nr_company, nr_branch, nr_patient),
  constraint patient_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint patient_vc_name_check  check (length(trim(vc_name)) > 0),
  constraint patient_vc_cpf_check   check (vc_cpf ~ '^[0-9]{11}$'),
  constraint patient_cpfs_check     check (vc_father_cpf ~ '^[0-9]{11}$'
                                       and vc_mother_cpf ~ '^[0-9]{11}$'
                                       and vc_guardian_cpf ~ '^[0-9]{11}$'),
  constraint patient_phones_check   check (vc_phone ~ '^[0-9]{10,11}$'
                                       and vc_mobile ~ '^[0-9]{10,11}$'
                                       and vc_phone_other ~ '^[0-9]{10,11}$'
                                       and vc_guardian_phone ~ '^[0-9]{10,11}$'),
  constraint patient_vc_zip_check   check (vc_zip ~ '^[0-9]{8}$'),
  constraint patient_vc_state_check check (vc_state ~ '^[A-Z]{2}$'),
  constraint patient_it_gender_check         check (it_gender in (1, 2, 3)),
  constraint patient_it_marital_status_check check (it_marital_status between 1 and 5),
  constraint patient_it_education_check      check (it_education between 1 and 4),
  constraint patient_it_source_check         check (it_source between 1 and 12 or it_source = 99),
  constraint patient_it_status_check         check (it_status in (1, 90))
);

alter table od.patient enable row level security;

-- CPF unico por filial (so quando informado)
create unique index patient_vc_cpf_uk
  on od.patient (nr_company, nr_branch, vc_cpf) where vc_cpf is not null;

-- busca por nome e lista ordenada
create index patient_vc_name_idx
  on od.patient (nr_company, nr_branch, lower(vc_name));

-- alertas de retorno do dia (agenda de contato)
create index patient_dt_return_alert_idx
  on od.patient (nr_company, nr_branch, dt_return_alert) where dt_return_alert is not null;

-- ---------------------------------------------------------------------------
-- od.patient_note - notas gerais do paciente (nr_note sequencial por paciente)
-- ---------------------------------------------------------------------------
create table od.patient_note (
  nr_company   bigint       not null,
  nr_branch    bigint       not null,
  nr_patient   bigint       not null,
  nr_note      bigint       not null,
  vc_note      text         not null,
  nr_user      bigint       not null,
  dh_note      timestamptz  not null default now(),
  it_status    smallint     not null default 1,
  nr_operator  bigint,
  dh_created   timestamptz  not null default now(),
  dh_updated   timestamptz  not null default now(),
  constraint patient_note_pk primary key (nr_company, nr_branch, nr_patient, nr_note),
  constraint patient_note_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint patient_note_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint patient_note_vc_note_check   check (length(trim(vc_note)) > 0),
  constraint patient_note_it_status_check check (it_status in (1, 90))
);

alter table od.patient_note enable row level security;

-- ---------------------------------------------------------------------------
-- Tela PATIENTS (uuid fixo = chave da permissao por perfil)
-- ---------------------------------------------------------------------------
insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000006', 'PATIENTS', 'Pacientes', 'Clínica', 12);
