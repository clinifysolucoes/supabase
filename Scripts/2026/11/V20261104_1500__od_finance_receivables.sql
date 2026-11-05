-- ============================================================================
-- Financeiro (schema od), fase 3a: recebiveis (cartao, boleto, cheque).
--
--   od.fin_account.it_type  + 4 recebiveis: conta de passagem onde fica o
--                           dinheiro recebido por cartao/boleto/cheque ate a
--                           operadora ou o banco pagar (criada sozinha)
--   od.fin_card_rate        taxas da filial por forma de pagamento e faixa de
--                           parcelas: percentual, tarifa fixa, prazo em dias e
--                           a conta onde o dinheiro cai
--   od.fin_receivable       recebivel: cada parcela do cartao (ou o boleto /
--                           cheque) com bruto, taxa, liquido, previsao e a
--                           confirmacao (transferencia da conta de passagem
--                           para a conta destino + despesa da taxa)
--
-- Leitura por RLS (private.fn_my_branches, em rls_od_policies.pgs); escrita so
-- pelas RPCs ad.fin_rate_save / ad.fin_receivable_settle e pela baixa
-- (fin_entry_settle, fin_entry_save, appointment_checkout).
-- ============================================================================

alter table od.fin_account drop constraint fin_account_it_type_check;
alter table od.fin_account add constraint fin_account_it_type_check check (it_type in (1, 2, 3, 4));

-- ---------------------------------------------------------------------------
-- od.fin_card_rate
-- ---------------------------------------------------------------------------
create table od.fin_card_rate (
  nr_company          bigint         not null,
  nr_branch           bigint         not null,
  nr_rate             bigint         not null,
  vc_name             varchar(60)    not null,
  it_payment_method   smallint       not null,
  qt_installments_min smallint       not null default 1,
  qt_installments_max smallint       not null default 1,
  pc_fee              numeric(5,2)   not null default 0,
  vl_fee_fixed        numeric(10,2)  not null default 0,
  qt_days             smallint       not null default 30,
  nr_account          bigint         not null,
  it_status           smallint       not null default 1,
  nr_operator         bigint,
  dh_created          timestamptz    not null default now(),
  dh_updated          timestamptz    not null default now(),
  constraint fin_card_rate_pk primary key (nr_company, nr_branch, nr_rate),
  constraint fin_card_rate_account_fk foreign key (nr_company, nr_branch, nr_account)
    references od.fin_account (nr_company, nr_branch, nr_account),
  constraint fin_card_rate_vc_name_check      check (length(trim(vc_name)) > 0),
  constraint fin_card_rate_method_check       check (it_payment_method in (3, 4, 6, 7)),
  constraint fin_card_rate_installments_check check (qt_installments_min between 1 and 24
                                                     and qt_installments_max between qt_installments_min and 24),
  constraint fin_card_rate_pc_fee_check       check (pc_fee between 0 and 100),
  constraint fin_card_rate_vl_fee_check       check (vl_fee_fixed >= 0),
  constraint fin_card_rate_qt_days_check      check (qt_days between 0 and 365),
  constraint fin_card_rate_it_status_check    check (it_status in (1, 90))
);

create unique index fin_card_rate_vc_name_uk on od.fin_card_rate (nr_company, nr_branch, lower(vc_name));

alter table od.fin_card_rate enable row level security;

-- ---------------------------------------------------------------------------
-- od.fin_receivable
-- ---------------------------------------------------------------------------
create table od.fin_receivable (
  nr_company         bigint         not null,
  nr_branch          bigint         not null,
  nr_receivable      bigint         not null,
  nr_entry           bigint         not null,
  nr_rate            bigint,
  it_payment_method  smallint       not null,
  nr_installment     smallint       not null default 1,
  qt_installments    smallint       not null default 1,
  vl_gross           numeric(14,2)  not null,
  vl_fee             numeric(14,2)  not null default 0,
  vl_net             numeric(14,2)  not null,
  dt_expected        date           not null,
  nr_account         bigint         not null,
  it_status          smallint       not null default 1,
  dt_received        date,
  vl_received        numeric(14,2),
  nr_transfer        bigint,
  nr_fee_entry       bigint,
  vc_reference       varchar(60),
  nr_user_created    bigint,
  nr_operator        bigint,
  dh_created         timestamptz    not null default now(),
  dh_updated         timestamptz    not null default now(),
  constraint fin_receivable_pk primary key (nr_company, nr_branch, nr_receivable),
  constraint fin_receivable_entry_fk foreign key (nr_company, nr_branch, nr_entry)
    references od.fin_entry (nr_company, nr_branch, nr_entry),
  constraint fin_receivable_rate_fk foreign key (nr_company, nr_branch, nr_rate)
    references od.fin_card_rate (nr_company, nr_branch, nr_rate),
  constraint fin_receivable_account_fk foreign key (nr_company, nr_branch, nr_account)
    references od.fin_account (nr_company, nr_branch, nr_account),
  constraint fin_receivable_transfer_fk foreign key (nr_company, nr_branch, nr_transfer)
    references od.fin_transfer (nr_company, nr_branch, nr_transfer),
  constraint fin_receivable_fee_entry_fk foreign key (nr_company, nr_branch, nr_fee_entry)
    references od.fin_entry (nr_company, nr_branch, nr_entry),
  constraint fin_receivable_user_created_fk foreign key (nr_user_created)
    references ad.app_user (nr_user),
  constraint fin_receivable_method_check   check (it_payment_method in (3, 4, 6, 7)),
  constraint fin_receivable_values_check   check (vl_gross > 0 and vl_fee >= 0 and vl_net = vl_gross - vl_fee),
  constraint fin_receivable_installment_check check (nr_installment between 1 and qt_installments
                                                     and qt_installments between 1 and 24),
  constraint fin_receivable_it_status_check check (it_status in (1, 2, 90)),
  constraint fin_receivable_received_check check ((it_status = 2 and dt_received is not null and vl_received > 0)
                                               or (it_status <> 2 and dt_received is null and vl_received is null))
);

create index fin_receivable_expected_idx on od.fin_receivable (nr_company, nr_branch, dt_expected);
create index fin_receivable_entry_idx on od.fin_receivable (nr_company, nr_branch, nr_entry);

alter table od.fin_receivable enable row level security;
