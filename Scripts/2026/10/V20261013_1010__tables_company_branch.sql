-- ============================================================================
-- ad.company (empresa) e ad.branch (filial).
--
-- Convencao de colunas: <tipo>_<nome> (sem o prefixo da tabela).
--   nr_ numerico/id   vc_ texto   it_ indicador/tipo   id_ boolean
--   dt_ date   dh_ timestamptz   qt_ quantidade   vl_ valor   pc_ percentual   uu_ uuid
-- Auditoria padrao (toda tabela): nr_operator, dh_created, dh_updated (trigger ad.trg_audit).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- ad.company
-- ---------------------------------------------------------------------------
create table ad.company (
  nr_company         bigint       generated always as identity primary key,
  vc_name            varchar(60)  not null,
  vc_cnpj            varchar(14),
  vc_email           varchar(200),
  vc_phone           varchar(20),
  it_size            smallint,
  vc_address         varchar(60),
  vc_address_number  varchar(10),
  vc_address_extra   varchar(60),
  vc_district        varchar(30),
  vc_city            varchar(30),
  vc_state           char(2),
  vc_zip_code        varchar(8),
  it_status          smallint     not null default 1,
  dh_status          timestamptz  not null default now(),
  id_blocked         boolean      not null default false,
  dh_blocked         timestamptz,
  vc_block_reason    varchar(200),
  nr_operator        bigint,
  dh_created         timestamptz  not null default now(),
  dh_updated         timestamptz  not null default now(),
  constraint company_vc_name_check     check (length(trim(vc_name)) > 0),
  constraint company_vc_cnpj_check     check (vc_cnpj is null or vc_cnpj ~ '^[A-Z0-9]{12}[0-9]{2}$'),
  constraint company_it_size_check     check (it_size is null or it_size in (10, 20, 30, 40, 50)),
  constraint company_it_status_check   check (it_status in (1, 90)),
  constraint company_vc_state_check    check (vc_state is null or vc_state ~ '^[A-Z]{2}$'),
  constraint company_vc_zip_code_check check (vc_zip_code is null or vc_zip_code ~ '^[0-9]{8}$')
);

create unique index company_vc_cnpj_uk on ad.company (vc_cnpj) where vc_cnpj is not null;

alter table ad.company enable row level security;

-- ---------------------------------------------------------------------------
-- ad.branch - PK composta (nr_company, nr_branch), numeracao por empresa
-- ---------------------------------------------------------------------------
create table ad.branch (
  nr_company             bigint       not null,
  nr_branch              bigint       not null,
  vc_name                varchar(60)  not null,
  vc_legal_name          varchar(80),
  vc_cnpj                varchar(14),
  vc_email               varchar(200),
  vc_phone               varchar(20),
  it_size                smallint,
  it_tax_regime          smallint,
  vc_state_registration  varchar(20),
  vc_city_registration   varchar(20),
  vc_address             varchar(60),
  vc_address_number      varchar(10),
  vc_address_extra       varchar(60),
  vc_district            varchar(30),
  vc_city                varchar(30),
  vc_state               char(2),
  vc_zip_code            varchar(8),
  vc_timezone            varchar(60)  not null default 'America/Sao_Paulo',
  id_main                boolean      not null default false,
  it_status              smallint     not null default 1,
  dh_status              timestamptz  not null default now(),
  id_blocked             boolean      not null default false,
  dh_blocked             timestamptz,
  vc_block_reason        varchar(200),
  nr_operator            bigint,
  dh_created             timestamptz  not null default now(),
  dh_updated             timestamptz  not null default now(),
  constraint branch_pk primary key (nr_company, nr_branch),
  constraint branch_nr_company_fk foreign key (nr_company) references ad.company (nr_company),
  constraint branch_vc_name_check       check (length(trim(vc_name)) > 0),
  constraint branch_vc_cnpj_check       check (vc_cnpj is null or vc_cnpj ~ '^[A-Z0-9]{12}[0-9]{2}$'),
  constraint branch_it_size_check       check (it_size is null or it_size in (10, 20, 30, 40, 50)),
  constraint branch_it_tax_regime_check check (it_tax_regime is null or it_tax_regime in (10, 20, 30, 40, 50)),
  constraint branch_it_status_check     check (it_status in (1, 90)),
  constraint branch_vc_state_check      check (vc_state is null or vc_state ~ '^[A-Z]{2}$'),
  constraint branch_vc_zip_code_check   check (vc_zip_code is null or vc_zip_code ~ '^[0-9]{8}$')
);

create unique index branch_vc_cnpj_uk on ad.branch (vc_cnpj) where vc_cnpj is not null;
create unique index branch_id_main_uk on ad.branch (nr_company) where id_main;

alter table ad.branch enable row level security;
