# frozen_string_literal: true

module SecID
  class CFI < Base
    # ISO 10962:2021 CFI code tables: the 14 categories, 78 groups, and the
    # per-position attribute matrix — each cell carrying both a symbol and the
    # authoritative ISO/SIX label string.
    #
    # Single source of truth for CFI validation, decoding, labels, predicates, and
    # generation. Transcribed from docs/research/iso-10962-2021-cfi-tables.md
    # (iotafinance's 2021 rendering; derivative tables single-sourced per R11).
    #
    # Shape:
    #   CATEGORIES[letter]              => [symbol, label]
    #   GROUPS[cat_letter][grp_letter]  => { symbol:, label:, attributes: [p3, p4, p5, p6] }
    #
    # Each of the four position entries is either {NA} (a pure not-applicable
    # position — accepts only +X+, omitted from decode) or a
    # +[meaning_symbol, { letter => [value_symbol, value_label] }]+ pair. The
    # letter +X+ is universally accepted in every position and decodes to
    # +:not_applicable+, so it is never listed in a value map.
    #
    # @api private
    # rubocop:disable Metrics/ModuleLength
    module Tables
      # Marker for a pure not-applicable attribute position (accepts only +X+).
      NA = nil

      # --- Shared value lists (mirror the standard's building blocks) ---------

      # Equity form (position 6 across E/D/R/M form positions).
      FORM = {
        'B' => [:bearer, 'Bearer'],
        'R' => [:registered, 'Registered'],
        'N' => [:bearer_registered, 'Bearer/Registered'],
        'M' => [:others, 'Others (miscellaneous)']
      }.freeze

      # Equity voting right (position 3 across E share groups).
      VOTING = {
        'V' => [:voting, 'Voting'],
        'N' => [:non_voting, 'Non-voting'],
        'R' => [:restricted_voting, 'Restricted voting'],
        'E' => [:enhanced_voting, 'Enhanced voting']
      }.freeze

      # Ownership/transfer/sales restrictions.
      OWNERSHIP = {
        'T' => [:restrictions, 'Restrictions'],
        'U' => [:free_of_restrictions, 'Free of restrictions']
      }.freeze

      # Equity payment status.
      PAYMENT = {
        'F' => [:fully_paid, 'Fully paid'],
        'O' => [:nil_paid, 'Nil paid'],
        'P' => [:partly_paid, 'Partly paid']
      }.freeze

      # Preference-share redemption (EP/EF position 4).
      PREF_REDEMPTION = {
        'R' => [:redeemable, 'Redeemable'],
        'E' => [:extendible, 'Extendible'],
        'T' => [:redeemable_extendible, 'Redeemable/Extendible'],
        'G' => [:exchangeable, 'Exchangeable'],
        'A' => [:redeemable_exchangeable_extendible, 'Redeemable/Exchangeable/Extendible'],
        'C' => [:redeemable_exchangeable, 'Redeemable/Exchangeable'],
        'N' => [:perpetual, 'Perpetual']
      }.freeze

      # Preference-share income (EP/EF position 5).
      PREF_INCOME = {
        'F' => [:fixed_rate, 'Fixed rate'],
        'C' => [:cumulative_fixed_rate, 'Cumulative, fixed rate'],
        'P' => [:participating, 'Participating'],
        'Q' => [:cumulative_participating, 'Cumulative, participating'],
        'A' => [:adjustable_rate, 'Adjustable/Variable rate'],
        'N' => [:normal_rate, 'Normal rate'],
        'U' => [:auction_rate, 'Auction rate']
      }.freeze

      # Debt guarantee (position 4 across most D groups).
      DEBT_GUARANTEE = {
        'T' => [:government_guarantee, 'Government/State guarantee'],
        'G' => [:joint_guarantee, 'Joint guarantee'],
        'S' => [:secured, 'Secured'],
        'U' => [:unsecured, 'Unsecured/Unguaranteed'],
        'P' => [:negative_pledge, 'Negative pledge'],
        'N' => [:senior, 'Senior'],
        'O' => [:senior_subordinated, 'Senior subordinated'],
        'Q' => [:junior, 'Junior'],
        'J' => [:junior_subordinated, 'Junior subordinated'],
        'C' => [:supranational, 'Supranational']
      }.freeze

      # Debt redemption/reimbursement (position 5 across most D groups).
      DEBT_REDEMPTION = {
        'F' => [:fixed_maturity, 'Fixed maturity'],
        'G' => [:fixed_maturity_with_call, 'Fixed maturity with call'],
        'C' => [:fixed_maturity_with_put, 'Fixed maturity with put'],
        'D' => [:fixed_maturity_with_put_and_call, 'Fixed maturity with put and call'],
        'A' => [:amortization_plan, 'Amortization plan'],
        'B' => [:amortization_with_call, 'Amortization plan with call'],
        'T' => [:amortization_with_put, 'Amortization plan with put'],
        'L' => [:amortization_with_put_and_call, 'Amortization plan with put and call'],
        'P' => [:perpetual, 'Perpetual'],
        'Q' => [:perpetual_with_call, 'Perpetual with call'],
        'R' => [:perpetual_with_put, 'Perpetual with put'],
        'E' => [:extendible, 'Extendible']
      }.freeze

      # Debt type of interest — DC/DW/DT/DY (F/Z/V/K, no cash payment).
      DEBT_INTEREST_FZVK = {
        'F' => [:fixed_rate, 'Fixed rate'],
        'Z' => [:zero_rate, 'Zero rate/discounted'],
        'V' => [:variable, 'Variable'],
        'K' => [:payment_in_kind, 'Payment in kind']
      }.freeze

      # Debt type of interest — DG/DA/DN (F/Z/V only).
      DEBT_INTEREST_FZV = {
        'F' => [:fixed_rate, 'Fixed rate'],
        'Z' => [:zero_rate, 'Zero rate/discounted'],
        'V' => [:variable, 'Variable']
      }.freeze

      # Structured-product distribution (DS/DE position 4).
      STRUCTURED_DISTRIBUTION = {
        'F' => [:fixed_interest, 'Fixed interest'],
        'D' => [:dividend, 'Dividend'],
        'V' => [:variable_interest, 'Variable interest'],
        'Y' => [:no_payments, 'No payments'],
        'M' => [:others, 'Others (miscellaneous)']
      }.freeze

      # Structured-product underlying assets (DS/DE position 6).
      STRUCTURED_UNDERLYING = {
        'B' => [:baskets, 'Baskets'],
        'S' => [:equities, 'Equities'],
        'D' => [:debt_instruments, 'Debt instruments'],
        'T' => [:commodities, 'Commodities'],
        'C' => [:currencies, 'Currencies'],
        'I' => [:indices, 'Indices'],
        'N' => [:interest_rates, 'Interest rates'],
        'M' => [:others, 'Others (miscellaneous)']
      }.freeze

      # Warrant/mini-future underlying assets (RW/RF position 3).
      WARRANT_UNDERLYING = {
        'B' => [:baskets, 'Baskets'],
        'S' => [:equities, 'Equities'],
        'D' => [:debt_instruments, 'Debt instruments/Interest rates'],
        'T' => [:commodities, 'Commodities'],
        'C' => [:currencies, 'Currencies'],
        'I' => [:indices, 'Indices'],
        'M' => [:others, 'Others (miscellaneous)']
      }.freeze

      # Exercise option style with Others (RW/RF position 6).
      EXERCISE_STYLE = {
        'A' => [:american, 'American'],
        'E' => [:european, 'European'],
        'B' => [:bermudan, 'Bermudan'],
        'M' => [:others, 'Others (miscellaneous)']
      }.freeze

      # Collective investment: closed/open-end (position 3).
      CIV_CLOSED_OPEN = {
        'O' => [:open_end, 'Open-end'],
        'C' => [:closed_end, 'Closed-end'],
        'M' => [:others, 'Others (miscellaneous)']
      }.freeze

      # Collective investment: distribution policy (position 4).
      CIV_DISTRIBUTION = {
        'I' => [:income_funds, 'Income funds'],
        'G' => [:accumulation_funds, 'Accumulation funds'],
        'J' => [:mixed_funds, 'Mixed funds']
      }.freeze

      # Collective investment: assets (position 5).
      CIV_ASSETS = {
        'R' => [:real_estate, 'Real estate'],
        'B' => [:debt_instruments, 'Debt instruments'],
        'E' => [:equities, 'Equities'],
        'V' => [:convertible_securities, 'Convertible securities'],
        'L' => [:mixed, 'Mixed'],
        'C' => [:commodities, 'Commodities'],
        'D' => [:derivatives, 'Derivatives'],
        'F' => [:referential_instruments, 'Referential instruments'],
        'K' => [:credits, 'Credits'],
        'M' => [:others, 'Others (miscellaneous)']
      }.freeze

      # Collective investment: security type & investor restrictions (S/Q/U/Y).
      CIV_SECURITY_FULL = {
        'S' => [:shares, 'Shares'],
        'Q' => [:shares_for_qualified_investors, 'Shares for qualified investors'],
        'U' => [:units, 'Units'],
        'Y' => [:units_for_qualified_investors, 'Units for qualified investors']
      }.freeze

      # Collective investment: security type (S/U only).
      CIV_SECURITY_SHORT = {
        'S' => [:shares, 'Shares'],
        'U' => [:units, 'Units']
      }.freeze

      # Listed-option exercise style (A/E/B, no Others).
      OPTION_STYLE = {
        'A' => [:american, 'American'],
        'E' => [:european, 'European'],
        'B' => [:bermudan, 'Bermudan']
      }.freeze

      # Listed-option underlying assets (OC/OP position 4).
      OPTION_UNDERLYING = {
        'B' => [:baskets, 'Baskets'],
        'S' => [:equities, 'Stock-Equities'],
        'D' => [:debt_instruments, 'Debt instruments'],
        'T' => [:commodities, 'Commodities'],
        'C' => [:currencies, 'Currencies'],
        'I' => [:indices, 'Indices'],
        'O' => [:options, 'Options'],
        'F' => [:futures, 'Futures'],
        'W' => [:swaps, 'Swaps'],
        'N' => [:interest_rates, 'Interest rates'],
        'M' => [:others, 'Others (miscellaneous)']
      }.freeze

      # Standardized flag (S/N).
      STANDARDIZED = {
        'S' => [:standardized, 'Standardized'],
        'N' => [:non_standardized, 'Non-standardized']
      }.freeze

      # Commodity underlying — extraction/agriculture form (FC/TT position 3).
      COMMODITY_ASSETS = {
        'E' => [:extraction_resources, 'Extraction resources'],
        'A' => [:agriculture, 'Agriculture'],
        'I' => [:industrial_products, 'Industrial products'],
        'S' => [:services, 'Services'],
        'N' => [:environmental, 'Environmental'],
        'P' => [:polypropylene_products, 'Polypropylene products'],
        'H' => [:generated_resources, 'Generated resources'],
        'M' => [:others, 'Others (miscellaneous)']
      }.freeze

      # Swap return/payout trigger (ST/SE position 4).
      RETURN_TRIGGER = {
        'P' => [:price, 'Price'],
        'D' => [:dividend, 'Dividend'],
        'V' => [:variance, 'Variance'],
        'L' => [:volatility, 'Volatility'],
        'T' => [:total_return, 'Total return'],
        'C' => [:contract_for_difference, 'Contract for difference'],
        'M' => [:others, 'Others (miscellaneous)']
      }.freeze

      # Non-listed option style and type (H position 4).
      H_OPTION_STYLE = {
        'A' => [:european_call, 'European call'],
        'B' => [:american_call, 'American call'],
        'C' => [:bermudan_call, 'Bermudan call'],
        'D' => [:european_put, 'European put'],
        'E' => [:american_put, 'American put'],
        'F' => [:bermudan_put, 'Bermudan put'],
        'G' => [:european_chooser, 'European chooser'],
        'H' => [:american_chooser, 'American chooser'],
        'I' => [:bermudan_chooser, 'Bermudan chooser']
      }.freeze

      # Non-listed option valuation method or trigger (H position 5).
      H_VALUATION = {
        'V' => [:vanilla, 'Vanilla'],
        'A' => [:asian, 'Asian'],
        'D' => [:digital, 'Digital (binary)'],
        'B' => [:barrier, 'Barrier'],
        'G' => [:digital_barrier, 'Digital barrier'],
        'L' => [:lookback, 'Lookback'],
        'P' => [:other_path_dependent, 'Other path-dependent'],
        'M' => [:others, 'Others (miscellaneous)']
      }.freeze

      # Delivery variants.
      DELIVERY_CP = { 'C' => [:cash, 'Cash'], 'P' => [:physical, 'Physical'] }.freeze
      DELIVERY_PN = { 'P' => [:physical, 'Physical'], 'N' => [:non_deliverable, 'Non-deliverable'] }.freeze
      DELIVERY_P  = { 'P' => [:physical, 'Physical'] }.freeze
      DELIVERY_PCN = {
        'P' => [:physical, 'Physical'],
        'C' => [:cash, 'Cash'],
        'N' => [:non_deliverable, 'Non-deliverable']
      }.freeze
      DELIVERY_CPE = {
        'C' => [:cash, 'Cash'],
        'P' => [:physical, 'Physical'],
        'E' => [:elect_at_settlement, 'Elect at settlement']
      }.freeze
      H_DELIVERY = {
        'C' => [:cash, 'Cash'],
        'P' => [:physical, 'Physical'],
        'E' => [:elect_at_exercise, 'Elect at exercise']
      }.freeze
      H_DELIVERY_N = H_DELIVERY.merge('N' => [:non_deliverable, 'Non-deliverable']).freeze
      H_DELIVERY_NA = H_DELIVERY_N.merge('A' => [:auction, 'Auction']).freeze

      # Forward return/payout trigger variants.
      FWD_TRIGGER_CSF = {
        'C' => [:contract_for_difference, 'Contract for difference'],
        'S' => [:spread_bet, 'Spread-bet'],
        'F' => [:forward_price, 'Forward price of underlying']
      }.freeze
      FWD_TRIGGER_SF = {
        'S' => [:spread_bet, 'Spread-bet'],
        'F' => [:forward_price, 'Forward price of underlying']
      }.freeze
      FWD_TRIGGER_CF = {
        'C' => [:contract_for_difference, 'Contract for difference'],
        'F' => [:forward_price, 'Forward price of underlying']
      }.freeze

      # --- Categories (position 1) --------------------------------------------

      CATEGORIES = {
        'E' => [:equity, 'Equities'],
        'C' => [:collective_investment_vehicles, 'Collective investment vehicles'],
        'D' => [:debt_instruments, 'Debt instruments'],
        'R' => [:entitlements, 'Entitlements (rights)'],
        'O' => [:listed_options, 'Listed options'],
        'F' => [:futures, 'Futures'],
        'S' => [:swaps, 'Swaps'],
        'H' => [:non_listed_options, 'Non-listed and complex listed options'],
        'I' => [:spot, 'Spot'],
        'J' => [:forwards, 'Forwards'],
        'K' => [:strategies, 'Strategies'],
        'L' => [:financing, 'Financing'],
        'T' => [:referential_instruments, 'Referential instruments'],
        'M' => [:miscellaneous, 'Others (miscellaneous)']
      }.freeze

      # --- Groups + attribute matrix (positions 2-6) --------------------------

      GROUPS = {
        'E' => {
          'S' => { symbol: :common_shares, label: 'Common/Ordinary shares',
                   attributes: [[:voting_right, VOTING], [:ownership_restrictions, OWNERSHIP],
                                [:payment_status, PAYMENT], [:form, FORM]] },
          'P' => { symbol: :preferred_shares, label: 'Preferred/Preference shares',
                   attributes: [[:voting_right, VOTING], [:redemption, PREF_REDEMPTION],
                                [:income, PREF_INCOME], [:form, FORM]] },
          'C' => { symbol: :convertible_common_shares, label: 'Common/Ordinary convertible shares',
                   attributes: [[:voting_right, VOTING], [:ownership_restrictions, OWNERSHIP],
                                [:payment_status, PAYMENT], [:form, FORM]] },
          'F' => { symbol: :convertible_preferred_shares, label: 'Preferred/Preference convertible shares',
                   attributes: [[:voting_right, VOTING], [:redemption, PREF_REDEMPTION],
                                [:income, PREF_INCOME], [:form, FORM]] },
          'L' => { symbol: :limited_partnership_units, label: 'Limited partnership units',
                   attributes: [[:voting_right, VOTING], [:ownership_restrictions, OWNERSHIP],
                                [:payment_status, PAYMENT], [:form, FORM]] },
          'D' => { symbol: :depositary_receipts, label: 'Depositary receipts on equities',
                   attributes: [[:underlying, {
                     'S' => [:common_shares, 'Common/Ordinary shares'],
                     'P' => [:preferred_shares, 'Preferred/Preference shares'],
                     'C' => [:convertible_common_shares, 'Common/Ordinary convertible shares'],
                     'F' => [:convertible_preferred_shares, 'Preferred/Preference convertible shares'],
                     'L' => [:limited_partnership_units, 'Limited partnership units'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:redemption, {
                     'R' => [:redeemable, 'Redeemable'],
                     'N' => [:perpetual, 'Perpetual'],
                     'B' => [:convertible, 'Convertible'],
                     'D' => [:convertible_redeemable, 'Convertible/Redeemable']
                   }], [:income, PREF_INCOME.merge('D' => [:dividends, 'Dividends'])],
                                [:form, FORM]] },
          'Y' => { symbol: :structured_instruments, label: 'Structured instruments (participation)',
                   attributes: [[:type, {
                     'A' => [:tracker_certificate, 'Tracker certificate'],
                     'B' => [:outperforming_certificate, 'Outperforming certificate'],
                     'C' => [:bonus_certificate, 'Bonus certificate'],
                     'D' => [:outperformance_bonus_certificate, 'Outperformance bonus certificate'],
                     'E' => [:twin_win_certificate, 'Twin-win certificate'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:distribution, {
                     'D' => [:dividend_payments, 'Dividend payments'],
                     'Y' => [:no_payments, 'No payments'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:repayment, {
                     'F' => [:cash_repayment, 'Cash repayment'],
                     'V' => [:physical_repayment, 'Physical repayment'],
                     'E' => [:elect_at_settlement, 'Elect at settlement'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:underlying_assets, {
                     'B' => [:baskets, 'Baskets'],
                     'S' => [:equities, 'Equities'],
                     'D' => [:debt_instruments, 'Debt instruments'],
                     'G' => [:derivatives, 'Derivatives'],
                     'T' => [:commodities, 'Commodities'],
                     'C' => [:currencies, 'Currencies'],
                     'I' => [:indices, 'Indices'],
                     'N' => [:interest_rates, 'Interest rates'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }]] },
          'M' => { symbol: :miscellaneous, label: 'Others (miscellaneous)',
                   attributes: [NA, NA, NA, [:form, FORM]] }
        },
        'C' => {
          'I' => { symbol: :standard_investment_funds, label: 'Standard (vanilla) funds',
                   attributes: [[:closed_open, CIV_CLOSED_OPEN], [:distribution_policy, CIV_DISTRIBUTION],
                                [:assets, CIV_ASSETS], [:security_type, CIV_SECURITY_FULL]] },
          'H' => { symbol: :hedge_funds, label: 'Hedge funds',
                   attributes: [[:investment_strategy, {
                     'D' => [:directional, 'Directional'],
                     'R' => [:relative_value, 'Relative value'],
                     'S' => [:security_selection, 'Security selection'],
                     'E' => [:event_driven, 'Event-driven'],
                     'A' => [:arbitrage, 'Arbitrage'],
                     'N' => [:multi_strategy, 'Multi-strategy'],
                     'L' => [:asset_based_lending, 'Asset-based lending'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, NA] },
          'B' => { symbol: :real_estate_investment_trusts, label: 'Real estate investment trusts (REITs)',
                   attributes: [[:closed_open, CIV_CLOSED_OPEN], [:distribution_policy, CIV_DISTRIBUTION],
                                NA, [:security_type, CIV_SECURITY_FULL]] },
          'E' => { symbol: :exchange_traded_funds, label: 'Exchange-traded funds (ETFs)',
                   attributes: [[:closed_open, CIV_CLOSED_OPEN], [:distribution_policy, CIV_DISTRIBUTION],
                                [:assets, CIV_ASSETS], [:security_type, CIV_SECURITY_SHORT]] },
          'S' => { symbol: :pension_funds, label: 'Pension funds',
                   attributes: [[:closed_open, CIV_CLOSED_OPEN], [:strategy_style, {
                     'B' => [:balanced_conservative, 'Balanced/Conservative'],
                     'G' => [:growth, 'Growth'],
                     'L' => [:life_style, 'Life style'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:type, {
                     'R' => [:defined_benefit, 'Defined benefit'],
                     'B' => [:defined_contribution, 'Defined contribution'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:security_type, CIV_SECURITY_SHORT]] },
          'F' => { symbol: :funds_of_funds, label: 'Funds of funds',
                   attributes: [[:closed_open, CIV_CLOSED_OPEN], [:distribution_policy, CIV_DISTRIBUTION],
                                [:underlying_fund_type, {
                                  'I' => [:standard_funds, 'Standard (vanilla)'],
                                  'H' => [:hedge_funds, 'Hedge funds'],
                                  'B' => [:reit, 'REIT'],
                                  'E' => [:etf, 'ETF'],
                                  'P' => [:private_equity, 'Private equity'],
                                  'M' => [:others, 'Others (miscellaneous)']
                                }], [:security_type, CIV_SECURITY_FULL]] },
          'P' => { symbol: :private_equity_funds, label: 'Private equity funds',
                   attributes: [[:closed_open, CIV_CLOSED_OPEN], [:distribution_policy, CIV_DISTRIBUTION],
                                [:assets, CIV_ASSETS], [:security_type, CIV_SECURITY_FULL]] },
          'M' => { symbol: :miscellaneous, label: 'Others (miscellaneous)',
                   attributes: [NA, NA, NA, [:security_type, CIV_SECURITY_FULL]] }
        },
        'D' => {
          'B' => { symbol: :bonds, label: 'Bonds',
                   attributes: [[:interest_type, {
                     'F' => [:fixed_rate, 'Fixed rate'],
                     'Z' => [:zero_rate, 'Zero rate/discounted'],
                     'V' => [:variable, 'Variable'],
                     'C' => [:cash_payment, 'Cash payment'],
                     'K' => [:payment_in_kind, 'Payment in kind']
                   }], [:guarantee, DEBT_GUARANTEE], [:redemption, DEBT_REDEMPTION], [:form, FORM]] },
          'C' => { symbol: :convertible_bonds, label: 'Convertible bonds',
                   attributes: [[:interest_type, DEBT_INTEREST_FZVK], [:guarantee, DEBT_GUARANTEE],
                                [:redemption, DEBT_REDEMPTION], [:form, FORM]] },
          'W' => { symbol: :bonds_with_warrants, label: 'Bonds with warrants attached',
                   attributes: [[:interest_type, DEBT_INTEREST_FZVK], [:guarantee, DEBT_GUARANTEE],
                                [:redemption, DEBT_REDEMPTION], [:form, FORM]] },
          'T' => { symbol: :medium_term_notes, label: 'Medium-term notes',
                   attributes: [[:interest_type, DEBT_INTEREST_FZVK], [:guarantee, DEBT_GUARANTEE],
                                [:redemption, DEBT_REDEMPTION], [:form, FORM]] },
          'S' => { symbol: :structured_products_with_protection,
                   label: 'Structured products (with capital protection)',
                   attributes: [[:type, {
                     'A' => [:capital_protection_with_participation,
                             'Capital protection certificate with participation'],
                     'B' => [:capital_protection_convertible, 'Capital protection convertible certificate'],
                     'C' => [:barrier_capital_protection, 'Barrier capital protection certificate'],
                     'D' => [:capital_protection_with_coupons, 'Capital protection certificate with coupons'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:distribution, STRUCTURED_DISTRIBUTION], [:repayment, {
                     'F' => [:fixed_cash_repayment, 'Fixed cash repayment (protected level only)'],
                     'V' => [:variable_cash_repayment, 'Variable cash repayment'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:underlying_assets, STRUCTURED_UNDERLYING]] },
          'E' => { symbol: :structured_products_without_protection,
                   label: 'Structured products (without capital protection)',
                   attributes: [[:type, {
                     'A' => [:discount_certificate, 'Discount certificate'],
                     'B' => [:barrier_discount_certificate, 'Barrier discount certificate'],
                     'C' => [:reverse_convertible, 'Reverse convertible'],
                     'D' => [:barrier_reverse_convertible, 'Barrier reverse convertible'],
                     'E' => [:express_certificate, 'Express certificate'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:distribution, STRUCTURED_DISTRIBUTION], [:repayment, {
                     'R' => [:repayment_in_cash, 'Repayment in cash'],
                     'S' => [:repayment_in_assets, 'Repayment in assets'],
                     'C' => [:repayment_in_assets_and_cash, 'Repayment in assets and cash'],
                     'T' => [:repayment_in_assets_or_cash, 'Repayment in assets or cash'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:underlying_assets, STRUCTURED_UNDERLYING]] },
          'G' => { symbol: :mortgage_backed_securities, label: 'Mortgage-backed securities (MBS)',
                   attributes: [[:interest_type, DEBT_INTEREST_FZV], [:guarantee, DEBT_GUARANTEE],
                                [:redemption, DEBT_REDEMPTION], [:form, FORM]] },
          'A' => { symbol: :asset_backed_securities, label: 'Asset-backed securities (ABS)',
                   attributes: [[:interest_type, DEBT_INTEREST_FZV], [:guarantee, DEBT_GUARANTEE],
                                [:redemption, DEBT_REDEMPTION], [:form, FORM]] },
          'N' => { symbol: :municipal_bonds, label: 'Municipal bonds',
                   attributes: [[:interest_type, DEBT_INTEREST_FZV], [:guarantee, DEBT_GUARANTEE],
                                [:redemption, DEBT_REDEMPTION], [:form, FORM]] },
          'D' => { symbol: :depositary_receipts, label: 'Depositary receipts on debt instruments',
                   attributes: [[:underlying, {
                     'B' => [:bonds, 'Bonds'],
                     'C' => [:convertible_bonds, 'Convertible bonds'],
                     'W' => [:bonds_with_warrants, 'Bonds with warrants attached'],
                     'T' => [:medium_term_notes, 'Medium-term notes'],
                     'Y' => [:money_market, 'Money-market instruments'],
                     'G' => [:mortgage_backed, 'Mortgage-backed securities (MBS)'],
                     'Q' => [:asset_backed, 'Asset-backed securities (ABS)'],
                     'N' => [:municipal_bonds, 'Municipal bonds'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:interest_type, {
                     'F' => [:fixed_rate, 'Fixed rate'],
                     'Z' => [:zero_rate, 'Zero rate/discounted'],
                     'V' => [:variable, 'Variable'],
                     'C' => [:cash_payment, 'Cash payment']
                   }], [:guarantee, DEBT_GUARANTEE], [:redemption, DEBT_REDEMPTION]] },
          'M' => { symbol: :miscellaneous, label: 'Others (miscellaneous)',
                   attributes: [[:type, {
                     'B' => [:bank_loan, 'Bank loan'],
                     'P' => [:promissory_note, 'Promissory note'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, [:form, FORM]] },
          'Y' => { symbol: :money_market_instruments, label: 'Money-market instruments',
                   attributes: [[:interest_type, DEBT_INTEREST_FZVK], [:guarantee, DEBT_GUARANTEE],
                                NA, [:form, FORM]] }
        },
        'R' => {
          'A' => { symbol: :allotment_rights, label: 'Allotments (bonus rights)',
                   attributes: [NA, NA, NA, [:form, FORM]] },
          'S' => { symbol: :subscription_rights, label: 'Subscription rights',
                   attributes: [[:underlying_assets, {
                     'S' => [:common_shares, 'Common/Ordinary shares'],
                     'P' => [:preferred_shares, 'Preferred/Preference shares'],
                     'C' => [:convertible_common_shares, 'Common/Ordinary convertible shares'],
                     'F' => [:convertible_preferred_shares, 'Preferred/Preference convertible shares'],
                     'B' => [:bonds, 'Bonds'],
                     'I' => [:combined_instruments, 'Combined instruments'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, [:form, FORM]] },
          'P' => { symbol: :purchase_rights, label: 'Purchase rights',
                   attributes: [[:underlying_assets, {
                     'S' => [:common_shares, 'Common/Ordinary shares'],
                     'P' => [:preferred_shares, 'Preferred/Preference shares'],
                     'C' => [:convertible_common_shares, 'Common/Ordinary convertible shares'],
                     'F' => [:convertible_preferred_shares, 'Preferred/Preference convertible shares'],
                     'B' => [:bonds, 'Bonds'],
                     'I' => [:combined_instruments, 'Combined instruments'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, [:form, FORM]] },
          'W' => { symbol: :warrants, label: 'Warrants',
                   attributes: [[:underlying_assets, WARRANT_UNDERLYING], [:warrant_type, {
                     'T' => [:traditional, 'Traditional'],
                     'N' => [:naked, 'Naked'],
                     'C' => [:covered, 'Covered']
                   }], [:call_put, {
                     'C' => [:call, 'Call'],
                     'P' => [:put, 'Put'],
                     'B' => [:call_and_put, 'Call and put']
                   }], [:exercise_style, EXERCISE_STYLE]] },
          'F' => { symbol: :mini_future_certificates, label: 'Mini-future / constant-leverage certificates',
                   attributes: [[:underlying_assets, WARRANT_UNDERLYING], [:barrier_dependency, {
                     'T' => [:barrier_underlying_based, 'Barrier underlying based'],
                     'N' => [:barrier_instrument_based, 'Barrier instrument based'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:long_short, {
                     'C' => [:long, 'Long'],
                     'P' => [:short, 'Short'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:exercise_style, EXERCISE_STYLE]] },
          'D' => { symbol: :depositary_receipts, label: 'Depositary receipts on entitlements',
                   attributes: [[:underlying, {
                     'A' => [:allotment_rights, 'Allotment (bonus) rights'],
                     'S' => [:subscription_rights, 'Subscription rights'],
                     'P' => [:purchase_rights, 'Purchase rights'],
                     'W' => [:warrants, 'Warrants'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, [:form, FORM]] },
          'M' => { symbol: :miscellaneous, label: 'Others (miscellaneous)',
                   attributes: [NA, NA, NA, NA] }
        },
        'O' => {
          'C' => { symbol: :call_options, label: 'Call options',
                   attributes: [[:exercise_style, OPTION_STYLE], [:underlying_assets, OPTION_UNDERLYING],
                                [:delivery, {
                                  'P' => [:physical, 'Physical'],
                                  'C' => [:cash, 'Cash'],
                                  'N' => [:non_deliverable, 'Non-deliverable'],
                                  'E' => [:elect_at_exercise, 'Elect at exercise']
                                }], [:standardized, STANDARDIZED]] },
          'P' => { symbol: :put_options, label: 'Put options',
                   attributes: [[:exercise_style, OPTION_STYLE], [:underlying_assets, OPTION_UNDERLYING],
                                [:delivery, {
                                  'P' => [:physical, 'Physical'],
                                  'C' => [:cash, 'Cash'],
                                  'N' => [:non_deliverable, 'Non-deliverable'],
                                  'E' => [:elect_at_exercise, 'Elect at exercise']
                                }], [:standardized, STANDARDIZED]] },
          'M' => { symbol: :miscellaneous, label: 'Others (miscellaneous)',
                   attributes: [NA, NA, NA, NA] }
        },
        'F' => {
          'F' => { symbol: :financial_futures, label: 'Financial futures',
                   attributes: [[:underlying_assets, {
                     'B' => [:baskets, 'Baskets'],
                     'S' => [:equities, 'Stock-Equities'],
                     'D' => [:debt_instruments, 'Debt instruments'],
                     'C' => [:currencies, 'Currencies'],
                     'I' => [:indices, 'Indices'],
                     'O' => [:options, 'Options'],
                     'F' => [:futures, 'Futures'],
                     'W' => [:swaps, 'Swaps'],
                     'N' => [:interest_rates, 'Interest rates'],
                     'V' => [:stock_dividend, 'Stock dividend'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:delivery, DELIVERY_PCN], [:standardized, STANDARDIZED], NA] },
          'C' => { symbol: :commodities_futures, label: 'Commodities futures',
                   attributes: [[:underlying_assets, COMMODITY_ASSETS], [:delivery, DELIVERY_PCN],
                                [:standardized, STANDARDIZED], NA] }
        },
        'S' => {
          'R' => { symbol: :rates, label: 'Rates',
                   attributes: [[:underlying_assets, {
                     'A' => [:basis_swap, 'Basis swap'],
                     'C' => [:fixed_floating, 'Fixed-floating'],
                     'D' => [:fixed_fixed, 'Fixed-fixed'],
                     'G' => [:inflation_rate_index, 'Inflation rate index'],
                     'H' => [:overnight_index_swap, 'Overnight index swap (OIS)'],
                     'Z' => [:zero_coupon, 'Zero coupon'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:notional, {
                     'C' => [:constant, 'Constant'],
                     'D' => [:accreting, 'Accreting'],
                     'I' => [:amortizing, 'Amortizing'],
                     'Y' => [:custom, 'Custom']
                   }], [:currency, {
                     'S' => [:single_currency, 'Single-currency'],
                     'C' => [:cross_currency, 'Cross-currency']
                   }], [:delivery, DELIVERY_CP]] },
          'T' => { symbol: :commodities, label: 'Commodities',
                   attributes: [[:underlying_assets, {
                     'J' => [:energy, 'Energy'],
                     'K' => [:metals, 'Metals'],
                     'A' => [:agriculture, 'Agriculture'],
                     'N' => [:environmental, 'Environmental'],
                     'G' => [:freight, 'Freight'],
                     'P' => [:polypropylene_products, 'Polypropylene products'],
                     'S' => [:fertilizer, 'Fertilizer'],
                     'T' => [:paper, 'Paper'],
                     'I' => [:index, 'Index'],
                     'Q' => [:multi_commodity, 'Multi-commodity'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:return_trigger, RETURN_TRIGGER], NA, [:delivery, DELIVERY_CPE]] },
          'E' => { symbol: :equity, label: 'Equity',
                   attributes: [[:underlying_assets, {
                     'S' => [:single_stock, 'Single stock'],
                     'I' => [:index, 'Index'],
                     'B' => [:basket, 'Basket'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:return_trigger, RETURN_TRIGGER], NA, [:delivery, DELIVERY_CPE]] },
          'C' => { symbol: :credit, label: 'Credit',
                   attributes: [[:underlying_assets, {
                     'U' => [:single_name, 'Single name'],
                     'V' => [:index_tranche, 'Index tranche'],
                     'I' => [:index, 'Index'],
                     'B' => [:basket, 'Basket'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:return_trigger, {
                     'C' => [:credit_default, 'Credit default'],
                     'T' => [:total_return, 'Total return'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:issuer_type, {
                     'C' => [:corporate, 'Corporate'],
                     'S' => [:sovereign, 'Sovereign'],
                     'L' => [:local, 'Local']
                   }], [:delivery, {
                     'C' => [:cash, 'Cash'],
                     'P' => [:physical, 'Physical'],
                     'A' => [:auction, 'Auction']
                   }]] },
          'F' => { symbol: :foreign_exchange, label: 'Foreign exchange',
                   attributes: [[:underlying_assets, {
                     'A' => [:spot_forward_swap, 'Spot-forward swap'],
                     'C' => [:forward_forward_swap, 'Forward-forward swap'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, [:delivery, DELIVERY_PN]] },
          'M' => { symbol: :miscellaneous, label: 'Others (miscellaneous)',
                   attributes: [[:underlying_assets, {
                     'P' => [:commercial_property, 'Commercial property (property derivative)'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, [:delivery, DELIVERY_CP]] }
        },
        'H' => {
          'R' => { symbol: :rates, label: 'Rates',
                   attributes: [[:underlying_assets, {
                     'A' => [:basis_swap, 'Basis swap'],
                     'C' => [:fixed_floating, 'Fixed-floating'],
                     'D' => [:fixed_fixed, 'Fixed-fixed'],
                     'G' => [:inflation_rate_index, 'Inflation rate index'],
                     'H' => [:overnight_index_swap, 'Overnight index swap (OIS)'],
                     'O' => [:options, 'Options'],
                     'R' => [:forwards, 'Forwards'],
                     'F' => [:futures, 'Futures'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:option_style, H_OPTION_STYLE], [:valuation, H_VALUATION], [:delivery, H_DELIVERY]] },
          'T' => { symbol: :commodities, label: 'Commodities',
                   attributes: [[:underlying_assets, {
                     'J' => [:energy, 'Energy'],
                     'K' => [:metals, 'Metals'],
                     'A' => [:agriculture, 'Agriculture'],
                     'N' => [:environmental, 'Environmental'],
                     'G' => [:freight, 'Freight'],
                     'P' => [:polypropylene_products, 'Polypropylene products'],
                     'S' => [:fertilizer, 'Fertilizer'],
                     'T' => [:paper, 'Paper'],
                     'I' => [:index, 'Index'],
                     'Q' => [:multi_commodity, 'Multi-commodity'],
                     'O' => [:options, 'Options'],
                     'R' => [:forwards, 'Forwards'],
                     'F' => [:futures, 'Futures'],
                     'W' => [:swaps, 'Swaps'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:option_style, H_OPTION_STYLE], [:valuation, H_VALUATION], [:delivery, H_DELIVERY]] },
          'E' => { symbol: :equity, label: 'Equity',
                   attributes: [[:underlying_assets, {
                     'S' => [:single_stock, 'Single stock'],
                     'I' => [:index, 'Index'],
                     'B' => [:basket, 'Basket'],
                     'O' => [:options, 'Options'],
                     'R' => [:forwards, 'Forwards'],
                     'F' => [:futures, 'Futures'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:option_style, H_OPTION_STYLE], [:valuation, H_VALUATION], [:delivery, H_DELIVERY]] },
          'C' => { symbol: :credit, label: 'Credit',
                   attributes: [[:underlying_assets, {
                     'U' => [:cds_single_name, 'CDS on a single name'],
                     'V' => [:cds_index_tranche, 'CDS on an index tranche'],
                     'I' => [:cds_index, 'CDS on an index'],
                     'W' => [:swaps, 'Swaps'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:option_style, H_OPTION_STYLE], [:valuation, H_VALUATION], [:delivery, H_DELIVERY]] },
          'F' => { symbol: :foreign_exchange, label: 'Foreign exchange',
                   attributes: [[:underlying_assets, {
                     'R' => [:forwards, 'Forwards'],
                     'F' => [:futures, 'Futures'],
                     'T' => [:spot_forward_swap, 'Spot-forward swap'],
                     'V' => [:volatility, 'Volatility'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:option_style, H_OPTION_STYLE], [:valuation, H_VALUATION], [:delivery, H_DELIVERY_N]] },
          'M' => { symbol: :miscellaneous, label: 'Others (miscellaneous)',
                   attributes: [[:underlying_assets, {
                     'P' => [:commercial_property, 'Commercial property'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:option_style, H_OPTION_STYLE], [:valuation, H_VALUATION], [:delivery, H_DELIVERY_NA]] }
        },
        'I' => {
          'F' => { symbol: :foreign_exchange, label: 'Foreign exchange',
                   attributes: [NA, NA, NA, [:delivery, DELIVERY_P]] },
          'T' => { symbol: :commodities, label: 'Commodities',
                   attributes: [[:underlying_assets, {
                     'A' => [:agriculture, 'Agriculture'],
                     'J' => [:energy, 'Energy'],
                     'K' => [:metals, 'Metals'],
                     'N' => [:environmental, 'Environmental'],
                     'P' => [:polypropylene_products, 'Polypropylene products'],
                     'S' => [:fertilizer, 'Fertilizer'],
                     'T' => [:paper, 'Paper'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, NA] }
        },
        'J' => {
          'E' => { symbol: :equity, label: 'Equity',
                   attributes: [[:underlying_assets, {
                     'S' => [:single_stock, 'Single stock'],
                     'I' => [:index, 'Index'],
                     'B' => [:basket, 'Basket'],
                     'O' => [:options, 'Options'],
                     'F' => [:futures, 'Futures']
                   }], NA, [:return_trigger, FWD_TRIGGER_CSF], [:delivery, DELIVERY_CP]] },
          'F' => { symbol: :foreign_exchange, label: 'Foreign exchange',
                   attributes: [[:underlying_assets, {
                     'T' => [:spot, 'Spot'],
                     'R' => [:forward, 'Forward'],
                     'O' => [:options, 'Options'],
                     'F' => [:futures, 'Futures']
                   }], NA, [:return_trigger, FWD_TRIGGER_CSF], [:delivery, DELIVERY_PCN]] },
          'C' => { symbol: :credit, label: 'Credit',
                   attributes: [[:underlying_assets, {
                     'A' => [:single_name, 'Single name'],
                     'I' => [:index, 'Index'],
                     'B' => [:basket, 'Basket'],
                     'C' => [:cds_single_name, 'CDS on a single name'],
                     'D' => [:cds_index, 'CDS on an index'],
                     'G' => [:cds_basket, 'CDS on a basket'],
                     'O' => [:options, 'Options']
                   }], NA, [:return_trigger, FWD_TRIGGER_SF], [:delivery, DELIVERY_PCN]] },
          'R' => { symbol: :rates, label: 'Rates',
                   attributes: [[:underlying_assets, {
                     'I' => [:interest_rate_index, 'Interest rate index'],
                     'O' => [:options, 'Options'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, [:return_trigger, FWD_TRIGGER_SF], [:delivery, DELIVERY_PCN]] },
          'T' => { symbol: :commodities, label: 'Commodities',
                   attributes: [[:underlying_assets, {
                     'A' => [:agriculture, 'Agriculture'],
                     'B' => [:basket, 'Basket'],
                     'G' => [:freight, 'Freight'],
                     'I' => [:index, 'Index'],
                     'J' => [:energy, 'Energy'],
                     'K' => [:metals, 'Metals'],
                     'N' => [:environmental, 'Environmental'],
                     'P' => [:polypropylene_products, 'Polypropylene products'],
                     'S' => [:fertilizer, 'Fertilizer'],
                     'T' => [:paper, 'Paper'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, [:return_trigger, FWD_TRIGGER_CF], [:delivery, DELIVERY_PCN]] }
        },
        'K' => {
          'R' => { symbol: :rates, label: 'Rates', attributes: [NA, NA, NA, NA] },
          'T' => { symbol: :commodities, label: 'Commodities', attributes: [NA, NA, NA, NA] },
          'E' => { symbol: :equity, label: 'Equity', attributes: [NA, NA, NA, NA] },
          'C' => { symbol: :credit, label: 'Credit', attributes: [NA, NA, NA, NA] },
          'F' => { symbol: :foreign_exchange, label: 'Foreign exchange', attributes: [NA, NA, NA, NA] },
          'Y' => { symbol: :mixed, label: 'Mixed assets', attributes: [NA, NA, NA, NA] },
          'M' => { symbol: :miscellaneous, label: 'Others (miscellaneous)', attributes: [NA, NA, NA, NA] }
        },
        'L' => {
          'L' => { symbol: :loan_lease, label: 'Loan-lease',
                   attributes: [[:underlying_assets, {
                     'A' => [:agriculture, 'Agriculture'],
                     'B' => [:baskets, 'Baskets'],
                     'J' => [:energy, 'Energy'],
                     'K' => [:metals, 'Metals'],
                     'N' => [:environmental, 'Environmental'],
                     'P' => [:polypropylene_products, 'Polypropylene products'],
                     'S' => [:fertilizer, 'Fertilizer'],
                     'T' => [:paper, 'Paper'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, [:delivery, DELIVERY_PCN]] },
          'R' => { symbol: :repurchase_agreements, label: 'Repurchase agreements',
                   attributes: [[:underlying_assets, {
                     'G' => [:general_collateral, 'General collateral'],
                     'S' => [:specific_security_collateral, 'Specific security collateral'],
                     'C' => [:cash_collateral, 'Cash collateral']
                   }], [:termination, {
                     'F' => [:flexible, 'Flexible'],
                     'N' => [:overnight, 'Overnight'],
                     'O' => [:open, 'Open'],
                     'T' => [:term, 'Term']
                   }], NA, [:delivery, {
                     'D' => [:delivery_versus_payment, 'Delivery versus payment'],
                     'H' => [:hold_in_custody, 'Hold-in-custody'],
                     'T' => [:tri_party, 'Tri-party']
                   }]] },
          'S' => { symbol: :securities_lending, label: 'Securities lending',
                   attributes: [[:underlying_assets, {
                     'C' => [:cash_collateral, 'Cash collateral'],
                     'G' => [:government_bonds, 'Government bonds'],
                     'P' => [:corporate_bonds, 'Corporate bonds'],
                     'T' => [:convertible_bonds, 'Convertible bonds'],
                     'E' => [:equity, 'Equity'],
                     'L' => [:letter_of_credit, 'Letter of credit'],
                     'D' => [:certificate_of_deposit, 'Certificate of deposit'],
                     'W' => [:warrants, 'Warrants'],
                     'K' => [:money_market_instruments, 'Money-market instruments'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:termination, {
                     'N' => [:overnight, 'Overnight'],
                     'O' => [:open, 'Open'],
                     'T' => [:term, 'Term']
                   }], NA, [:delivery, {
                     'D' => [:delivery_versus_payment, 'Delivery versus payment'],
                     'F' => [:free_of_payment, 'Free of payment'],
                     'H' => [:hold_in_custody, 'Hold-in-custody'],
                     'T' => [:tri_party, 'Tri-party']
                   }]] }
        },
        'T' => {
          'C' => { symbol: :currencies, label: 'Currencies',
                   attributes: [[:type, {
                     'N' => [:national_currency, 'National currency'],
                     'L' => [:legacy_currency, 'Legacy currency'],
                     'C' => [:bullion_coins, 'Bullion coins'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, NA] },
          'T' => { symbol: :commodities, label: 'Commodities',
                   attributes: [[:underlying_assets, COMMODITY_ASSETS], NA, NA, NA] },
          'R' => { symbol: :interest_rates, label: 'Interest rates',
                   attributes: [[:interest_rate_type, {
                     'N' => [:nominal, 'Nominal'],
                     'V' => [:variable, 'Variable'],
                     'F' => [:fixed, 'Fixed'],
                     'R' => [:real, 'Real'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:calculation_frequency, {
                     'D' => [:daily, 'Daily'],
                     'W' => [:weekly, 'Weekly'],
                     'N' => [:monthly, 'Monthly'],
                     'Q' => [:quarterly, 'Quarterly'],
                     'S' => [:semi_annually, 'Semi-annually'],
                     'A' => [:annually, 'Annually'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA] },
          'I' => { symbol: :indices, label: 'Indices',
                   attributes: [[:asset_class, {
                     'E' => [:equities, 'Equities'],
                     'D' => [:debt, 'Debt'],
                     'F' => [:collective_investment_vehicles, 'Collective investment vehicles'],
                     'R' => [:real_estate, 'Real estate'],
                     'T' => [:commodities, 'Commodities'],
                     'C' => [:currencies, 'Currencies'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:weighting, {
                     'P' => [:price_weighted, 'Price weighted'],
                     'C' => [:capitalization_weighted, 'Capitalization weighted'],
                     'E' => [:equal_weighted, 'Equal weighted'],
                     'F' => [:modified_market_cap_weighted, 'Modified market-cap weighted'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:return_type, {
                     'P' => [:price_return, 'Price return'],
                     'N' => [:net_total_return, 'Net total return'],
                     'G' => [:gross_total_return, 'Gross total return'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA] },
          'B' => { symbol: :baskets, label: 'Baskets',
                   attributes: [[:composition, {
                     'E' => [:equities, 'Equities'],
                     'D' => [:debt, 'Debt'],
                     'F' => [:collective_investment_vehicles, 'Collective investment vehicles'],
                     'I' => [:indices, 'Indices'],
                     'T' => [:commodities, 'Commodities'],
                     'C' => [:currencies, 'Currencies'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, NA] },
          'D' => { symbol: :stock_dividends, label: 'Stock dividends',
                   attributes: [[:equity_type, {
                     'S' => [:common_shares, 'Common/Ordinary shares'],
                     'P' => [:preferred_shares, 'Preferred/Preference shares'],
                     'C' => [:convertible_common_shares, 'Common/Ordinary convertible shares'],
                     'F' => [:convertible_preferred_shares, 'Preferred/Preference convertible shares'],
                     'L' => [:limited_partnership_units, 'Limited partnership units'],
                     'K' => [:collective_investment_vehicles, 'Collective investment vehicles'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, NA] },
          'M' => { symbol: :miscellaneous, label: 'Others (miscellaneous)',
                   attributes: [NA, NA, NA, NA] }
        },
        'M' => {
          'C' => { symbol: :combined_instruments, label: 'Combined instruments',
                   attributes: [[:components, {
                     'S' => [:combination_of_shares, 'Combination of shares'],
                     'B' => [:combination_of_bonds, 'Combination of bonds'],
                     'H' => [:share_and_bond, 'Share and bond'],
                     'A' => [:share_and_warrant, 'Share and warrant'],
                     'W' => [:warrant_and_warrant, 'Warrant and warrant'],
                     'U' => [:fund_unit_and_other, 'Fund unit and other components'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], [:ownership_restrictions, OWNERSHIP], NA, [:form, FORM]] },
          'M' => { symbol: :other_assets, label: 'Other assets',
                   attributes: [[:further_grouping, {
                     'R' => [:real_estate_deeds, 'Real estate deeds'],
                     'I' => [:insurance_policies, 'Insurance policies'],
                     'E' => [:escrow_receipts, 'Escrow receipts'],
                     'T' => [:trade_finance_instruments, 'Trade finance instruments'],
                     'N' => [:carbon_credit, 'Carbon credit'],
                     'P' => [:precious_metal_receipts, 'Precious metal receipts'],
                     'S' => [:other_otc_derivatives, 'Other OTC derivative products'],
                     'M' => [:others, 'Others (miscellaneous)']
                   }], NA, NA, NA] }
        }
      }.freeze

      # Cross-position rule for group ED (depositary receipts on equities): when
      # the underlying instrument (position 3) is common/ordinary shares (S) or
      # limited partnership units (L), the redemption/conversion position
      # (position 4) accepts only N (perpetual) or X.
      ED_REDEMPTION_RULE = {
        category: 'E',
        group: 'D',
        underlying_position: 0,
        redemption_position: 1,
        restricted_underlyings: %w[S L].freeze,
        allowed_redemptions: %w[N X].freeze
      }.freeze

      # Whether the ED (depositary receipts on equities) cross-position redemption
      # rule applies to the given group and attribute letters — i.e. this is an
      # E/D code whose underlying triggers the redemption restriction, so the
      # redemption position must hold one of {ED_REDEMPTION_RULE}'s allowed values.
      # Shared by generation (enforcement) and validation so the two never drift.
      #
      # @param category_code [String]
      # @param group_code [String]
      # @param letters [Array<String>] the four attribute letters (positions 3-6)
      # @return [Boolean]
      def self.ed_rule_applies?(category_code, group_code, letters)
        rule = ED_REDEMPTION_RULE
        category_code == rule[:category] && group_code == rule[:group] &&
          rule[:restricted_underlyings].include?(letters[rule[:underlying_position]])
      end

      DeepFreeze.call(CATEGORIES)
      DeepFreeze.call(GROUPS)

      # @param category_code [String]
      # @param group_code [String]
      # @return [Hash, nil] the group definition, or nil if unknown
      def self.group(category_code, group_code)
        GROUPS.dig(category_code, group_code)
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
