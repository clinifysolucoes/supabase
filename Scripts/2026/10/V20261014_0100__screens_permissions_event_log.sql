-- ============================================================================
-- Telas, permissoes por perfil e log de atividades.
--
-- ad.screen                 catalogo GLOBAL de telas do app (sem nr_company):
--                           uuid estavel (igual em todos os ambientes), codigo
--                           usado pelo app para rotear e nome bonito para a tela.
-- ad.access_profile_screen  permissao do perfil em cada tela:
--                           linha existe = pode LER; id_create / id_update
--                           liberam criar e alterar. Perfil nivel 100
--                           (administrador) ignora esta tabela: tem tudo.
-- ad.event_log              o que aconteceu no sistema (quem, quando, em qual
--                           tela, qual acao, qual registro, resumo e detalhe).
--                           Gravado pelas RPCs via ad.fn_event_log; nunca pelo app.
-- Login/acesso continua em ad.access_log.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- ad.screen
-- ---------------------------------------------------------------------------
create table ad.screen (
  uu_screen    uuid         not null default gen_random_uuid(),
  vc_code      varchar(30)  not null,
  vc_name      varchar(60)  not null,
  vc_group     varchar(30),
  nr_order     smallint     not null default 0,
  it_status    smallint     not null default 1,
  nr_operator  bigint,
  dh_created   timestamptz  not null default now(),
  dh_updated   timestamptz  not null default now(),
  constraint screen_pk primary key (uu_screen),
  constraint screen_vc_code_uk unique (vc_code),
  constraint screen_vc_code_check   check (vc_code ~ '^[A-Z][A-Z0-9_]{1,29}$'),
  constraint screen_vc_name_check   check (length(trim(vc_name)) > 0),
  constraint screen_it_status_check check (it_status in (1, 90))
);

alter table ad.screen enable row level security;

-- ---------------------------------------------------------------------------
-- ad.access_profile_screen
-- ---------------------------------------------------------------------------
create table ad.access_profile_screen (
  nr_company   bigint       not null,
  nr_profile   bigint       not null,
  uu_screen    uuid         not null,
  id_read      boolean      not null default true,
  id_create    boolean      not null default false,
  id_update    boolean      not null default false,
  nr_operator  bigint,
  dh_created   timestamptz  not null default now(),
  dh_updated   timestamptz  not null default now(),
  constraint access_profile_screen_pk primary key (nr_company, nr_profile, uu_screen),
  constraint access_profile_screen_profile_fk foreign key (nr_company, nr_profile)
    references ad.access_profile (nr_company, nr_profile) on delete cascade,
  constraint access_profile_screen_screen_fk foreign key (uu_screen) references ad.screen (uu_screen),
  constraint access_profile_screen_read_check check (id_read or (not id_create and not id_update))
);

create index access_profile_screen_uu_screen_idx on ad.access_profile_screen (uu_screen);

alter table ad.access_profile_screen enable row level security;

-- ---------------------------------------------------------------------------
-- ad.event_log
-- ---------------------------------------------------------------------------
create table ad.event_log (
  nr_event     bigint        generated always as identity primary key,
  nr_company   bigint,
  nr_branch    bigint,
  nr_user      bigint        not null,
  uu_screen    uuid,
  vc_action    varchar(20)   not null,
  vc_entity    varchar(40)   not null,
  vc_key       varchar(60),
  vc_summary   varchar(200)  not null,
  js_detail    jsonb,
  dh_event     timestamptz   not null default now(),
  nr_operator  bigint,
  dh_created   timestamptz   not null default now(),
  dh_updated   timestamptz   not null default now(),
  constraint event_log_nr_user_fk   foreign key (nr_user)   references ad.app_user (nr_user),
  constraint event_log_uu_screen_fk foreign key (uu_screen) references ad.screen (uu_screen),
  constraint event_log_vc_action_check check (vc_action in ('CREATE', 'UPDATE', 'DELETE', 'OTHER'))
);

create index event_log_nr_company_idx on ad.event_log (nr_company, dh_event desc);
create index event_log_nr_user_idx    on ad.event_log (nr_user, dh_event desc);

alter table ad.event_log enable row level security;

-- ---------------------------------------------------------------------------
-- Telas do app (uuids fixos: a permissao e por uuid e precisa ser a mesma em
-- homologacao e producao). Tela nova = nova linha aqui (ou versionada futura).
-- DASHBOARD e implicita para todo usuario logado (session_context).
-- ---------------------------------------------------------------------------
insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000001', 'DASHBOARD', 'Dashboard',        null,            10),
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000002', 'USERS',     'Usuários',         'Administração', 20),
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000003', 'PROFILES',  'Perfis de acesso', 'Administração', 30),
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000004', 'LOGS',      'Logs',             'Administração', 40);
