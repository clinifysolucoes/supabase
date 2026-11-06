-- ============================================================================
-- Recibos numerados de recebimentos.
--
--   od.fin_receipt     recibo de uma conta a receber paga: numero sequencial
--                        por filial (nr_receipt) e o numero impresso
--                        (vc_number = prefixo + numero), pagador, valor, data
--                        e forma do pagamento. Um recibo ativo por conta;
--                        cancelado nao libera o numero (o proximo e outro).
--   od.branch_setting  + vc_receipt_prefix  prefixo do numero impresso (ex. REC-)
--                      + nr_next_receipt    proximo numero de recibo
--
-- Leitura por RLS (private.fn_my_branches); escrita so pelas RPCs
-- ad.fin_receipt_issue / ad.fin_receipt_cancel (tela FINANCE) e, nas
-- configuracoes, ad.settings_save.
-- ============================================================================

alter table od.branch_setting add column vc_receipt_prefix varchar(10) not null default '';
alter table od.branch_setting add column nr_next_receipt bigint not null default 1;
alter table od.branch_setting add constraint branch_setting_next_receipt_check check (nr_next_receipt >= 1);

create table od.fin_receipt (
  nr_company         bigint         not null,
  nr_branch          bigint         not null,
  nr_receipt         bigint         not null,
  vc_number          varchar(30)    not null,
  nr_entry           bigint         not null,
  vl_amount          numeric(14,2)  not null,
  dt_paid            date           not null,
  it_payment_method  smallint,
  vc_payer_name      varchar(120)   not null,
  vc_payer_document  varchar(14),
  vc_description     varchar(200)   not null,
  it_status          smallint       not null default 1,
  vc_cancel_reason   varchar(200),
  nr_user_created    bigint,
  nr_operator        bigint,
  dh_created         timestamptz    not null default now(),
  dh_updated         timestamptz    not null default now(),
  constraint fin_receipt_pk primary key (nr_company, nr_branch, nr_receipt),
  constraint fin_receipt_entry_fk foreign key (nr_company, nr_branch, nr_entry)
    references od.fin_entry (nr_company, nr_branch, nr_entry),
  constraint fin_receipt_user_created_fk foreign key (nr_user_created)
    references ad.app_user (nr_user),
  constraint fin_receipt_amount_check     check (vl_amount > 0),
  constraint fin_receipt_payer_check      check (length(trim(vc_payer_name)) > 0),
  constraint fin_receipt_document_check   check (vc_payer_document is null or vc_payer_document ~ '^[0-9]{11}$|^[0-9]{14}$'),
  constraint fin_receipt_it_status_check  check (it_status in (1, 90))
);

create unique index fin_receipt_number_uk on od.fin_receipt (nr_company, nr_branch, vc_number);
create unique index fin_receipt_entry_uk on od.fin_receipt (nr_company, nr_branch, nr_entry) where it_status = 1;

alter table od.fin_receipt enable row level security;
