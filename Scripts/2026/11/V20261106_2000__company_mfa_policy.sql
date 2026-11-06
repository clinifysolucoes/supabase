-- ============================================================================
-- Autenticacao em dois fatores (2FA, app autenticador / TOTP do Supabase Auth)
-- obrigatoria por empresa.
--
--   ad.company  + it_mfa_policy  0 nao exige | 1 exige dos administradores da
--                                 empresa | 2 exige de todos os usuarios
--
-- A regra vale em private.fn_my_branches: sem o segundo fator confirmado na
-- sessao (JWT aal2), a empresa fica fora do acesso de quem precisa dele e o
-- ad.session_context a mostra em "blocked" com SESSION_MFA_REQUIRED.
-- Escrita so por ad.company_update (administrador, ja com 2FA para ligar).
-- ============================================================================

alter table ad.company add column it_mfa_policy smallint not null default 0;
alter table ad.company add constraint company_mfa_policy_check check (it_mfa_policy in (0, 1, 2));
