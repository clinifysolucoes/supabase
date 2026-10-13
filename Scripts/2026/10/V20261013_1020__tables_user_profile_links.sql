-- ============================================================================
-- ad.app_user            usuario (espelho de auth.users + dados do app)
-- ad.access_profile      perfil de acesso
-- ad.company_user        empresa x usuario
-- ad.branch_user_profile empresa x filial x usuario x perfil
-- ad.access_log          log de acesso
--
-- Autenticacao (senha, token, 2FA, tentativas negadas) e do Supabase Auth
-- (auth.users). Aqui ficam apenas os dados de negocio e os vinculos.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- ad.app_user
-- ---------------------------------------------------------------------------
create table ad.app_user (
  nr_user          bigint       generated always as identity primary key,
  uu_auth          uuid         not null,
  vc_name          varchar(60)  not null,
  vc_email         varchar(200),
  vc_cpf           varchar(11),
  vc_phone         varchar(20),
  vc_mobile        varchar(20),
  vc_avatar_url    text,
  it_level         smallint     not null default 0,
  it_status        smallint     not null default 1,
  vc_block_reason  varchar(200),
  dh_last_login    timestamptz,
  nr_operator      bigint,
  dh_created       timestamptz  not null default now(),
  dh_updated       timestamptz  not null default now(),
  constraint app_user_uu_auth_uk unique (uu_auth),
  constraint app_user_uu_auth_fk foreign key (uu_auth) references auth.users (id) on delete cascade,
  constraint app_user_vc_name_check   check (length(trim(vc_name)) > 0),
  constraint app_user_vc_cpf_check    check (vc_cpf is null or vc_cpf ~ '^[0-9]{11}$'),
  constraint app_user_it_level_check  check (it_level in (0, 100)),
  constraint app_user_it_status_check check (it_status in (1, 80, 90))
);

create unique index app_user_vc_email_uk on ad.app_user (vc_email) where vc_email is not null;
create unique index app_user_vc_cpf_uk   on ad.app_user (vc_cpf)   where vc_cpf is not null;

alter table ad.app_user enable row level security;

-- ---------------------------------------------------------------------------
-- ad.access_profile - perfil de acesso por empresa, numeracao por empresa
-- ---------------------------------------------------------------------------
create table ad.access_profile (
  nr_company   bigint       not null,
  nr_profile   bigint       not null,
  vc_name      varchar(30)  not null,
  it_level     smallint     not null default 0,
  it_status    smallint     not null default 1,
  nr_operator  bigint,
  dh_created   timestamptz  not null default now(),
  dh_updated   timestamptz  not null default now(),
  constraint access_profile_pk primary key (nr_company, nr_profile),
  constraint access_profile_nr_company_fk foreign key (nr_company) references ad.company (nr_company),
  constraint access_profile_vc_name_uk unique (nr_company, vc_name),
  constraint access_profile_vc_name_check   check (length(trim(vc_name)) > 0),
  constraint access_profile_it_level_check  check (it_level between 0 and 100),
  constraint access_profile_it_status_check check (it_status in (1, 90))
);

alter table ad.access_profile enable row level security;

-- ---------------------------------------------------------------------------
-- ad.company_user - usuario x empresa (multi-empresa)
-- ---------------------------------------------------------------------------
create table ad.company_user (
  nr_company       bigint       not null,
  nr_user          bigint       not null,
  nr_company_user  bigint       not null,
  it_status        smallint     not null default 1,
  vc_block_reason  varchar(200),
  nr_operator      bigint,
  dh_created       timestamptz  not null default now(),
  dh_updated       timestamptz  not null default now(),
  constraint company_user_pk primary key (nr_company, nr_user),
  constraint company_user_nr_company_fk foreign key (nr_company) references ad.company (nr_company),
  constraint company_user_nr_user_fk    foreign key (nr_user)    references ad.app_user (nr_user),
  constraint company_user_nr_company_user_uk unique (nr_company, nr_company_user),
  constraint company_user_it_status_check check (it_status in (1, 80, 90))
);

create index company_user_nr_user_idx on ad.company_user (nr_user);

alter table ad.company_user enable row level security;

-- ---------------------------------------------------------------------------
-- ad.branch_user_profile - usuario x filial x perfil (multi-filial)
-- ---------------------------------------------------------------------------
create table ad.branch_user_profile (
  nr_company   bigint       not null,
  nr_branch    bigint       not null,
  nr_user      bigint       not null,
  nr_profile   bigint       not null,
  nr_operator  bigint,
  dh_created   timestamptz  not null default now(),
  dh_updated   timestamptz  not null default now(),
  constraint branch_user_profile_pk primary key (nr_company, nr_branch, nr_user, nr_profile),
  constraint branch_user_profile_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch) on delete cascade,
  constraint branch_user_profile_company_user_fk foreign key (nr_company, nr_user)
    references ad.company_user (nr_company, nr_user) on delete cascade,
  constraint branch_user_profile_access_profile_fk foreign key (nr_company, nr_profile)
    references ad.access_profile (nr_company, nr_profile)
);

create index branch_user_profile_nr_user_idx on ad.branch_user_profile (nr_user, nr_company, nr_branch);

alter table ad.branch_user_profile enable row level security;

-- ---------------------------------------------------------------------------
-- ad.access_log - log de sessao (gravado por ad.session_context)
-- ---------------------------------------------------------------------------
create table ad.access_log (
  nr_access       bigint       generated always as identity primary key,
  nr_user         bigint       not null,
  nr_company      bigint,
  nr_branch       bigint,
  it_app          smallint,
  vc_ip           varchar(60),
  vc_device       varchar(200),
  vc_user_agent   varchar(800),
  vc_app_version  varchar(30),
  dh_access       timestamptz  not null default now(),
  nr_operator     bigint,
  dh_created      timestamptz  not null default now(),
  dh_updated      timestamptz  not null default now(),
  constraint access_log_nr_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint access_log_it_app_check check (it_app is null or it_app in (1, 2, 3, 9))
);

create index access_log_nr_user_idx on ad.access_log (nr_user, dh_access desc);

alter table ad.access_log enable row level security;

-- ---------------------------------------------------------------------------
-- Grants (as tabelas ja existem; os default privileges valem para as futuras)
-- ---------------------------------------------------------------------------
grant select on all tables in schema ad to authenticated;
grant all on all tables in schema ad to service_role;
grant all on all sequences in schema ad to service_role;
