-- ============================================================================
-- Tela Relatorios (REPORTS): faltas e desmarcacoes, aniversariantes,
-- procedimentos executados e pagamentos e comissoes (ad.report_get).
-- Ler em REPORTS libera a tela; o relatorio de comissoes exige tambem ler em
-- FINANCE.
-- ============================================================================

insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000011', 'REPORTS', 'Relatórios', 'Gestão', 16);
