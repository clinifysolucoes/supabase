-- ============================================================================
-- Seguranca: pedir usuario e senha de um administrador antes de imprimir ou
-- exportar dados (como em Configuracoes > Seguranca do Clinicorp), deixando
-- rastreavel quem pediu, quem liberou e o que foi.
--
--   ad.company               + id_auth_print   imprimir exige um administrador
--                            + id_auth_export  exportar exige um administrador
--   ad.access_authorization  pedido de liberacao: quem pede (sessao do usuario)
--                            e o administrador que libera (o app confere o login
--                            dele numa sessao separada e chama access_authorize).
--                            Vale 10 minutos; a exportacao do banco
--                            (ad.data_export) consome a liberacao.
-- ============================================================================

alter table ad.company add column id_auth_print boolean not null default false;
alter table ad.company add column id_auth_export boolean not null default false;

create table ad.access_authorization (
  nr_authorization  bigint        generated always as identity primary key,
  uu_request        uuid          not null default gen_random_uuid(),
  nr_company        bigint        not null,
  nr_branch         bigint        not null,
  it_kind           smallint      not null,
  vc_target         varchar(120)  not null,
  nr_user           bigint        not null,
  nr_user_admin     bigint,
  dh_authorized     timestamptz,
  dh_used           timestamptz,
  dh_expires        timestamptz   not null default now() + interval '10 minutes',
  nr_operator       bigint,
  dh_created        timestamptz   not null default now(),
  dh_updated        timestamptz   not null default now(),
  constraint access_authorization_uu_uk unique (uu_request),
  constraint access_authorization_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint access_authorization_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint access_authorization_admin_fk foreign key (nr_user_admin) references ad.app_user (nr_user),
  constraint access_authorization_kind_check check (it_kind in (1, 2)),
  constraint access_authorization_admin_check check ((nr_user_admin is null) = (dh_authorized is null))
);
create index access_authorization_company_idx on ad.access_authorization (nr_company, dh_created);
alter table ad.access_authorization enable row level security;
