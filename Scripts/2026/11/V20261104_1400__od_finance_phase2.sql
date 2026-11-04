-- ============================================================================
-- Financeiro (schema od), fase 2: atendimento e caixa.
--
--   od.fin_cash_session  caixa do dia por pessoa: abertura (valor contado),
--                        fechamento (valor contado x esperado) numa conta do
--                        tipo caixa; uma sessao aberta por conta e por usuario
--   od.fin_transfer      transferencia entre contas (sangria = do caixa para
--                        outra conta, suprimento = de outra conta para o caixa)
--   od.fin_entry         + nr_appointment  atendimento que gerou o lancamento
--                          (fechamento da consulta)
--                        + nr_professional comissao do profissional
--                        + nr_cash_session sessao de caixa em que foi paga
--
-- Saldo da conta = saldo inicial + receitas pagas - despesas pagas
--                  + transferencias recebidas - transferencias enviadas.
-- Leitura por RLS (private.fn_my_branches, em rls_od_policies.pgs); escrita so
-- pelas RPCs ad.fin_cash_* / ad.fin_transfer_save / ad.appointment_checkout.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- od.fin_cash_session
-- ---------------------------------------------------------------------------
create table od.fin_cash_session (
  nr_company      bigint         not null,
  nr_branch       bigint         not null,
  nr_session      bigint         not null,
  nr_account      bigint         not null,
  nr_user         bigint         not null,
  dh_open         timestamptz    not null default now(),
  vl_open         numeric(14,2)  not null default 0,
  dh_close        timestamptz,
  vl_counted      numeric(14,2),
  vl_expected     numeric(14,2),
  it_status       smallint       not null default 1,
  vc_notes        varchar(500),
  nr_user_closed  bigint,
  nr_operator     bigint,
  dh_created      timestamptz    not null default now(),
  dh_updated      timestamptz    not null default now(),
  constraint fin_cash_session_pk primary key (nr_company, nr_branch, nr_session),
  constraint fin_cash_session_account_fk foreign key (nr_company, nr_branch, nr_account)
    references od.fin_account (nr_company, nr_branch, nr_account),
  constraint fin_cash_session_user_fk foreign key (nr_user)
    references ad.app_user (nr_user),
  constraint fin_cash_session_user_closed_fk foreign key (nr_user_closed)
    references ad.app_user (nr_user),
  constraint fin_cash_session_it_status_check check (it_status in (1, 2)),
  constraint fin_cash_session_close_check     check ((it_status = 1 and dh_close is null and vl_counted is null)
                                                  or (it_status = 2 and dh_close is not null and vl_counted is not null
                                                      and vl_expected is not null))
);

create unique index fin_cash_session_open_account_uk on od.fin_cash_session (nr_company, nr_branch, nr_account)
  where it_status = 1;
create unique index fin_cash_session_open_user_uk on od.fin_cash_session (nr_company, nr_branch, nr_user)
  where it_status = 1;
create index fin_cash_session_open_idx on od.fin_cash_session (nr_company, nr_branch, dh_open);

alter table od.fin_cash_session enable row level security;

-- ---------------------------------------------------------------------------
-- od.fin_transfer
-- ---------------------------------------------------------------------------
create table od.fin_transfer (
  nr_company        bigint         not null,
  nr_branch         bigint         not null,
  nr_transfer       bigint         not null,
  it_type           smallint       not null default 1,
  nr_account_from   bigint         not null,
  nr_account_to     bigint         not null,
  vl_amount         numeric(14,2)  not null,
  dt_transfer       date           not null,
  vc_description    varchar(140),
  nr_cash_session   bigint,
  it_status         smallint       not null default 1,
  nr_user_created   bigint,
  nr_operator       bigint,
  dh_created        timestamptz    not null default now(),
  dh_updated        timestamptz    not null default now(),
  constraint fin_transfer_pk primary key (nr_company, nr_branch, nr_transfer),
  constraint fin_transfer_from_fk foreign key (nr_company, nr_branch, nr_account_from)
    references od.fin_account (nr_company, nr_branch, nr_account),
  constraint fin_transfer_to_fk foreign key (nr_company, nr_branch, nr_account_to)
    references od.fin_account (nr_company, nr_branch, nr_account),
  constraint fin_transfer_session_fk foreign key (nr_company, nr_branch, nr_cash_session)
    references od.fin_cash_session (nr_company, nr_branch, nr_session),
  constraint fin_transfer_user_created_fk foreign key (nr_user_created)
    references ad.app_user (nr_user),
  constraint fin_transfer_it_type_check   check (it_type in (1, 2, 3)),
  constraint fin_transfer_accounts_check  check (nr_account_from <> nr_account_to),
  constraint fin_transfer_vl_amount_check check (vl_amount > 0),
  constraint fin_transfer_it_status_check check (it_status in (1, 90))
);

create index fin_transfer_date_idx on od.fin_transfer (nr_company, nr_branch, dt_transfer);

alter table od.fin_transfer enable row level security;

-- ---------------------------------------------------------------------------
-- od.fin_entry: atendimento, profissional e sessao de caixa
-- ---------------------------------------------------------------------------
alter table od.fin_entry
  add column nr_appointment  bigint,
  add column nr_professional bigint,
  add column nr_cash_session bigint,
  add constraint fin_entry_appointment_fk foreign key (nr_company, nr_branch, nr_appointment)
    references od.appointment (nr_company, nr_branch, nr_appointment),
  add constraint fin_entry_professional_fk foreign key (nr_company, nr_branch, nr_professional)
    references od.professional (nr_company, nr_branch, nr_professional),
  add constraint fin_entry_cash_session_fk foreign key (nr_company, nr_branch, nr_cash_session)
    references od.fin_cash_session (nr_company, nr_branch, nr_session);

create index fin_entry_appointment_idx on od.fin_entry (nr_company, nr_branch, nr_appointment)
  where nr_appointment is not null;
create index fin_entry_session_idx on od.fin_entry (nr_company, nr_branch, nr_cash_session)
  where nr_cash_session is not null;
