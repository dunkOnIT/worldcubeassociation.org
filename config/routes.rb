# frozen_string_literal: true

require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  use_doorkeeper do
    controllers applications: 'oauth/applications'
  end
  use_doorkeeper_openid_connect

  # Starburst announcements, see https://github.com/starburstgem/starburst#installation
  mount Starburst::Engine => '/starburst'

  # Sidekiq web UI, see https://github.com/sidekiq/sidekiq/wiki/Devise
  # Specifically referring to results because WRT needs access to this on top of regular admins.
  authenticate :user, ->(user) { user.can_admin_results? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  # Don't expose Paypal routes in production until we're reading to launch
  unless Rails.env.production?
    post 'registration/:id/create-paypal-order' => 'registrations#create_paypal_order', as: :registration_create_paypal_order
    post 'registration/:id/capture-paypal-payment/:order_id' => 'registrations#capture_paypal_payment', as: :registration_capture_paypal_payment
    get 'competitions/:id/paypal-return' => 'competitions#paypal_return', as: :competitions_paypal_return
    post 'competitions/:id/disconnect_paypal' => 'competitions#disconnect_paypal', as: :competition_disconnect_paypal
  end

  # Prevent account deletion, and overrides the sessions controller for 2FA.
  #  https://github.com/plataformatec/devise/wiki/How-To:-Disable-user-from-destroying-their-account
  devise_for :users, skip: :registrations, controllers: { sessions: "sessions" }
  devise_scope :user do
    resource :registration,
             only: [:new, :create],
             path: 'users',
             path_names: { new: 'sign_up' },
             controller: 'accounts/registrations',
             as: :user_registration do
               get :cancel
             end
    post 'users/generate-email-otp' => 'sessions#generate_email_otp'
    post 'users/authenticate-sensitive' => 'users#authenticate_user_for_sensitive_edit'
    delete 'users/sign-out-other' => 'sessions#destroy_other', as: :destroy_other_user_sessions
  end
  post 'registration/:id/refund/:payment_id' => 'registrations#refund_payment', as: :registration_payment_refund
  post 'registration/:id/load-payment-intent' => 'registrations#load_payment_intent', as: :registration_payment_intent
  get 'registration/:id/payment-completion' => 'registrations#payment_completion', as: :registration_payment_completion
  post 'registration/stripe-webhook' => 'registrations#stripe_webhook', as: :registration_stripe_webhook
  get 'registration/stripe-denomination' => 'registrations#stripe_denomination', as: :registration_stripe_denomination
  resources :users, only: [:index, :edit, :update]
  get 'profile/edit' => 'users#edit'
  post 'profile/enable-2fa' => 'users#enable_2fa'
  post 'profile/disable-2fa' => 'users#disable_2fa'
  post 'profile/generate-2fa-backup' => 'users#regenerate_2fa_backup_codes'
  post 'profile/acknowledge-cookies' => 'users#acknowledge_cookies'

  get 'profile/claim_wca_id' => 'users#claim_wca_id'
  get 'profile/claim_wca_id/select_nearby_delegate' => 'users#select_nearby_delegate'

  get 'users/:id/edit/avatar_thumbnail' => 'users#edit_avatar_thumbnail', as: :users_avatar_thumbnail_edit
  get 'users/:id/edit/pending_avatar_thumbnail' => 'users#edit_pending_avatar_thumbnail', as: :users_pending_avatar_thumbnail_edit
  get 'admin/avatars' => 'admin/avatars#index'
  post 'admin/avatars' => 'admin/avatars#update_all'

  get 'map' => 'competitions#embedable_map'

  get 'competitions/mine' => 'competitions#my_competitions', as: :my_comps
  get 'competitions/for_senior(/:user_id)' => 'competitions#for_senior', as: :competitions_for_senior
  get 'competitions/:id/enable_v2' => "competitions#enable_v2", as: :enable_v2
  post 'competitions/bookmark' => 'competitions#bookmark', as: :bookmark
  post 'competitions/unbookmark' => 'competitions#unbookmark', as: :unbookmark

  get 'competitions/v2/:id' => 'competitions_v2#show', as: :competitions_v2
  get 'competitions/v2/:id/*all' => 'competitions_v2#show'

  resources :competitions do
    get 'edit/admin' => 'competitions#admin_edit', as: :admin_edit

    get 'announcement_data' => 'competitions#announcement_data', as: :announcement_data
    get 'user_preferences' => 'competitions#user_preferences', as: :user_preferences
    get 'confirmation_data' => 'competitions#confirmation_data', as: :confirmation_data

    put 'confirm' => 'competitions#confirm', as: :confirm
    put 'announce' => 'competitions#announce', as: :announce
    put 'cancel' => 'competitions#cancel_or_uncancel', as: :cancel
    put 'close_full_registration' => 'competitions#close_full_registration', as: :close_full_registration

    patch 'user_preference/notifications' => 'competitions#update_user_notifications', as: :update_user_notifications

    get 'results/podiums' => 'competitions#show_podiums'
    get 'results/all' => 'competitions#show_all_results'
    get 'results/by_person' => 'competitions#show_results_by_person'
    get 'scrambles' => 'competitions#show_scrambles'

    patch 'registrations/selected' => 'registrations#do_actions_for_selected', as: :registrations_do_actions_for_selected
    post 'registrations/export' => 'registrations#export', as: :registrations_export
    get 'registrations/import' => 'registrations#import', as: :registrations_import
    post 'registrations/import' => 'registrations#do_import', as: :registrations_do_import
    get 'registrations/add' => 'registrations#add', as: :registrations_add
    post 'registrations/add' => 'registrations#do_add', as: :registrations_do_add
    get 'registrations/psych-sheet' => 'registrations#psych_sheet', as: :psych_sheet
    get 'registrations/psych-sheet/:event_id' => 'registrations#psych_sheet_event', as: :psych_sheet_event
    resources :registrations, only: [:index, :update, :create, :edit, :destroy], shallow: true
    get 'edit/registrations' => 'registrations#edit_registrations'
    get 'register' => 'registrations#register'
    resources :competition_tabs, except: [:show], as: :tabs, path: :tabs
    get 'tabs/:id/reorder' => "competition_tabs#reorder", as: :tab_reorder
    # Delegate views and action
    get 'submit-results' => 'results_submission#new', as: :submit_results_edit
    post 'submit-results' => 'results_submission#create', as: :submit_results
    post 'upload-json' => 'results_submission#upload_json', as: :upload_results_json
    # WRT views and action
    get '/admin/upload-results' => "admin#new_results", as: :admin_upload_results_edit
    get '/admin/check-existing-results' => "admin#check_competition_results", as: :admin_check_existing_results
    post '/admin/check-existing-results' => "admin#do_check_competition_results", as: :admin_run_validators
    post '/admin/upload-json' => "admin#create_results", as: :admin_upload_results
    post '/admin/clear-submission' => "admin#clear_results_submission", as: :clear_results_submission
    get '/admin/import-results' => 'admin#import_results', as: :admin_import_results
    get '/admin/result-inbox-steps' => 'admin#result_inbox_steps', as: :admin_result_inbox_steps
    post '/admin/import-inbox-results' => 'admin#import_inbox_results', as: :admin_import_inbox_results
    delete '/admin/inbox-data' => 'admin#delete_inbox_data', as: :admin_delete_inbox_data
    delete '/admin/results-data' => 'admin#delete_results_data', as: :admin_delete_results_data
    get '/admin/results/:round_id/new' => 'admin/results#new', as: :new_result
  end
  unless EnvConfig.WCA_LIVE_SITE?
    scope :payment do
      get '/config' => 'payment#payment_config'
      get '/finish' => 'payment#payment_finish'
      get '/refunds' => 'payment#available_refunds'
      get '/refund' => 'payment#payment_refund'
    end
  end

  get 'competitions/:competition_id/report/edit' => 'delegate_reports#edit', as: :delegate_report_edit
  get 'competitions/:competition_id/report' => 'delegate_reports#show', as: :delegate_report
  patch 'competitions/:competition_id/report' => 'delegate_reports#update'

  get 'competitions/:id/payment_setup' => 'competitions#payment_setup', as: :competitions_payment_setup
  get 'stripe-connect' => 'competitions#stripe_connect', as: :competitions_stripe_connect
  get 'competitions/:id/events/edit' => 'competitions#edit_events', as: :edit_events
  get 'competitions/:id/schedule/edit' => 'competitions#edit_schedule', as: :edit_schedule
  get 'competitions/edit/nearby_competitions' => 'competitions#nearby_competitions', as: :nearby_competitions
  get 'competitions/edit/series_eligible_competitions' => 'competitions#series_eligible_competitions', as: :series_eligible_competitions
  get 'competitions/edit/colliding_registration_start_competitions' => 'competitions#colliding_registration_start_competitions', as: :colliding_registration_start_competitions
  get 'competitions/:id/edit/clone_competition' => 'competitions#clone_competition', as: :clone_competition
  get 'competitions/edit/calculate_dues' => 'competitions#calculate_dues', as: :calculate_dues

  get 'competitions/edit/nearby-competitions-json' => 'competitions#nearby_competitions_json', as: :nearby_competitions_json
  get 'competitions/edit/registration-collisions-json' => 'competitions#registration_collisions_json', as: :registration_collisions_json
  get 'competitions/edit/series-eligible-competitions-json' => 'competitions#series_eligible_competitions_json', as: :series_eligible_competitions_json

  get 'results/rankings', to: redirect('results/rankings/333/single', status: 302)
  get 'results/rankings/333mbf/average',
      to: redirect(status: 302) { |params, request| URI.parse(request.original_url).query ? "results/rankings/333mbf/single?#{URI.parse(request.original_url).query}" : "results/rankings/333mbf/single" }
  get 'results/rankings/:event_id', to: redirect('results/rankings/%{event_id}/single', status: 302)
  get 'results/rankings/:event_id/:type' => 'results#rankings', as: :rankings
  get 'results/records' => 'results#records', as: :records

  scope '/admin' do
    resources :results, except: [:index, :new], controller: 'admin/results'
    post 'results' => 'admin/results#create'
    get 'events_data/:competition_id' => 'admin/results#show_events_data', as: :competition_events_data
  end

  get "media/validate" => 'media#validate', as: :validate_media
  resources :media, only: [:index, :new, :create, :edit, :update, :destroy]

  get 'export/results' => 'database#results_export', as: :db_results_export
  get 'export/results/WCA_export.sql' => 'database#sql_permalink', as: :sql_permalink
  get 'export/results/WCA_export.tsv' => 'database#tsv_permalink', as: :tsv_permalink
  get 'export/developer' => 'database#developer_export', as: :db_dev_export
  get 'export/developer/wca-developer-database-dump', to: redirect(DbDumpHelper.public_s3_path(DbDumpHelper::DEVELOPER_EXPORT_SQL_PERMALINK))
  # redirect from the old path that used to be linked on GitHub
  get 'wst/wca-developer-database-dump.zip', to: redirect(DbDumpHelper.public_s3_path(DbDumpHelper::DEVELOPER_EXPORT_SQL_PERMALINK))

  get 'persons/new_id' => 'admin/persons#generate_ids'
  resources :persons, only: [:index, :show]
  post 'persons' => 'admin/persons#create'

  resources :polls, only: [:edit, :new, :vote, :create, :update, :index, :destroy]
  get 'polls/:id/vote' => 'votes#vote', as: 'polls_vote'
  get 'polls/:id/results' => 'polls#results', as: 'polls_results'

  resources :teams, only: [:index, :update, :edit]

  resources :votes, only: [:create, :update]

  post 'competitions/:id/post_results' => 'competitions#post_results', as: :competition_post_results
  post 'competitions/:id/disconnect_stripe' => 'competitions#disconnect_stripe', as: :competition_disconnect_stripe

  get 'panel' => 'panel#index'
  get 'panel/delegate-crash-course', to: redirect('https://documents.worldcubeassociation.org/edudoc/delegate-crash-course/delegate_crash_course.pdf', status: 302)
  get 'panel/pending-claims(/:user_id)' => 'panel#pending_claims_for_subordinate_delegates', as: 'pending_claims'
  scope 'panel' do
    get 'wfc' => 'panel#wfc', as: :panel_wfc
    get 'wrt' => 'panel#wrt', as: :panel_wrt
    get 'wst' => 'panel#wst', as: :panel_wst
    get 'board' => 'panel#board', as: :panel_board
    get 'leader' => 'panel#leader', as: :panel_leader
    get 'senior_delegate' => 'panel#senior_delegate', as: :panel_senior_delegate
  end
  resources :notifications, only: [:index]

  root 'posts#homepage'
  resources :posts
  get 'rss' => 'posts#rss'

  post 'upload/image', to: 'upload#image'

  get 'robots' => 'static_pages#robots'

  get 'server-status' => 'server_status#index'

  get 'translations', to: redirect('translations/status', status: 302)
  get 'translations/status' => 'translations#index'
  get 'translations/edit' => 'translations#edit'
  patch 'translations/update' => 'translations#update'

  get 'about' => 'static_pages#about'
  get 'documents' => 'static_pages#documents'
  get 'education' => 'static_pages#education'
  get 'delegates' => 'static_pages#delegates'
  get 'disclaimer' => 'static_pages#disclaimer'
  get 'faq' => 'static_pages#faq'
  get 'logo' => 'static_pages#logo'
  get 'media-instagram' => 'static_pages#media_instagram'
  get 'merch' => 'static_pages#merch'
  get 'organizer-guidelines' => 'static_pages#organizer_guidelines'
  get 'privacy' => 'static_pages#privacy'
  get 'score-tools' => 'static_pages#score_tools'
  get 'speedcubing-history' => 'static_pages#speedcubing_history'
  get 'teams-committees' => 'static_pages#teams_committees'
  get 'tutorial' => redirect('/education', status: 302)
  get 'wca-workbook-assistant' => 'static_pages#wca_workbook_assistant'
  get 'wca-workbook-assistant-versions' => 'static_pages#wca_workbook_assistant_versions'
  get 'translators' => 'static_pages#translators'
  get 'officers-and-board' => 'static_pages#officers_and_board'

  resources :regional_organizations, only: [:new, :create, :update, :edit, :destroy], path: '/regional-organizations'
  get 'organizations' => 'regional_organizations#index'
  get 'admin/regional-organizations' => 'regional_organizations#admin'

  get 'disciplinary' => 'wdc#root'

  get 'contact' => 'contacts#index'
  post 'contact' => 'contacts#website_create'
  get 'contact/dob' => 'contacts#dob'
  post 'contact/dob' => 'contacts#dob_create'

  get '/regulations' => 'regulations#show', id: 'index'
  get '/regulations/wca-regulations-and-guidelines', to: redirect('https://regulations.worldcubeassociation.org/wca-regulations-and-guidelines.pdf', status: 302)
  get '/regulations/about' => 'regulations#about'
  get '/regulations/countries' => 'regulations#countries'
  get '/regulations/scrambles' => 'regulations#scrambles'
  get '/regulations/guidelines' => 'regulations#guidelines'
  get '/regulations/translations' => 'regulations#translations'
  get '/regulations/translations/:language' => 'regulations_translations#translated_regulation'
  get '/regulations/translations/:language/guidelines' => 'regulations_translations#translated_guidelines'
  get '/regulations/translations/:language/:pdf' => "regulations_translations#translated_pdfs"
  get '/regulations/history' => 'regulations#history'
  get '/regulations/history/official/:id' => 'regulations#historical_regulations'
  get '/regulations/history/official/:id/guidelines' => 'regulations#historical_guidelines'
  get '/regulations/history/official/:id/wca-regulations-and-guidelines', to: redirect('https://regulations.worldcubeassociation.org/history/official/%{id}/wca-regulations-and-guidelines.pdf', status: 302)

  get '/admin' => 'admin#index'
  get '/admin/all-voters' => 'admin#all_voters', as: :eligible_voters
  get '/admin/leader-senior-voters' => 'admin#leader_senior_voters', as: :leader_senior_voters
  get '/admin/check_results' => 'admin#check_results'
  get '/admin/validation_competitions' => "admin#compute_validation_competitions"
  post '/admin/check_results' => 'admin#do_check_results'
  get '/admin/merge_people' => 'admin#merge_people'
  post '/admin/merge_people' => 'admin#do_merge_people'
  get '/admin/edit_person' => 'admin#edit_person'
  get '/admin/fix_results' => 'admin#fix_results'
  get '/admin/fix_results_selector' => 'admin#fix_results_selector', as: :admin_fix_results_ajax
  get '/admin/person_data' => 'admin#person_data'
  get '/admin/compute_auxiliary_data' => 'admin#compute_auxiliary_data'
  get '/admin/do_compute_auxiliary_data' => 'admin#do_compute_auxiliary_data'
  get '/admin/generate_exports' => 'admin#generate_exports'
  get '/admin/generate_db_token' => 'admin#generate_db_token'
  get '/admin/do_generate_dev_export' => 'admin#do_generate_dev_export'
  get '/admin/do_generate_public_export' => 'admin#do_generate_public_export'
  get '/admin/check_regional_records' => 'admin#check_regional_records'
  get '/admin/override_regional_records' => 'admin#override_regional_records'
  post '/admin/override_regional_records' => 'admin#do_override_regional_records'
  get '/admin/finish_persons' => 'admin#finish_persons'
  post '/admin/finish_persons' => 'admin#do_finish_persons'
  get '/admin/finish_unfinished_persons' => 'admin#finish_unfinished_persons'
  get '/admin/complete_persons' => 'admin#complete_persons'
  post '/admin/complete_persons' => 'admin#do_complete_persons'
  get '/admin/peek_unfinished_results' => 'admin#peek_unfinished_results'
  get '/admin/anonymize_person' => 'admin#anonymize_person'
  post '/admin/anonymize_person' => 'admin#do_anonymize_person'
  get '/admin/reassign_wca_id' => 'admin#reassign_wca_id'
  get '/admin/validate_reassign_wca_id' => 'admin#validate_reassign_wca_id'
  post '/admin/reassign_wca_id' => 'admin#do_reassign_wca_id'

  get '/search' => 'search_results#index'

  post '/render_markdown' => 'markdown_renderer#render_markdown'

  patch '/update_locale/:locale' => 'application#update_locale', as: :update_locale

  get '/.well-known/change-password' => redirect('/profile/edit?section=password', status: 302)

  # WFC section
  scope 'wfc' do
    get '/competitions_export' => 'wfc#competition_export', defaults: { format: :csv }, as: :wfc_competitions_export
    resources :country_bands, only: [:index, :update, :edit], path: '/country-bands'
  end

  scope :archive do
    # NOTE: This is meant for displaying old content of the phpBB forum. It is DEPRECATED!
    resources :forums, only: [:index, :show]
    resources :forum_topics, only: [:show]
  end

  resources :incidents do
    patch '/mark_as/:kind' => 'incidents#mark_as', as: :mark_as
  end

  get '/sso-discourse' => 'users#sso_discourse'
  get '/redirect/wac-survey' => 'users#wac_survey'

  scope 'admin' do
    get '/posting-index' => 'admin/results#posting_index', as: :results_posting_dashboard
    post '/start-posting' => 'admin/results#start_posting'
  end

  namespace :api do
    get '/', to: redirect('/api/v0', status: 302)
    namespace :internal do
      namespace :v1 do
        get '/users/:id/permissions' => 'permissions#index'
        post '/users/competitor-info' => 'users#competitor_info'
        post '/payment/init_stripe' => 'payment#init'
      end
    end
    namespace :v0 do
      get '/' => 'api#help'
      get '/me' => 'api#me'
      get '/auth/results' => 'api#auth_results'
      get '/export/public' => 'api#export_public'
      get '/scramble-program' => 'api#scramble_program'
      get '/search' => 'api#omni_search'
      get '/search/posts' => 'api#posts_search'
      get '/search/competitions' => 'api#competitions_search'
      get '/search/users' => 'api#users_search', as: :search_users
      get '/search/persons' => 'api#persons_search', as: :search_persons
      get '/search/regulations' => 'api#regulations_search'
      get '/search/incidents' => 'api#incidents_search'
      get '/users' => 'users#show_users_by_id'
      get '/users/me' => 'users#show_me'
      get '/users/me/personal_records' => 'users#personal_records'
      get '/users/me/preferred_events' => 'users#preferred_events'
      get '/users/me/permissions' => 'users#permissions'
      get '/users/me/bookmarks' => 'users#bookmarked_competitions'
      get '/users/me/token' => 'users#token'
      get '/users/:id' => 'users#show_user_by_id', constraints: { id: /\d+/ }
      get '/users/:wca_id' => 'users#show_user_by_wca_id', as: :user
      get '/delegates' => 'api#delegates'
      get '/persons' => "persons#index"
      get '/persons/:wca_id' => "persons#show", as: :person
      get '/persons/:wca_id/results' => "persons#results", as: :person_results
      get '/persons/:wca_id/competitions' => "persons#competitions", as: :person_competitions
      get '/geocoding/search' => 'geocoding#get_location_from_query', as: :geocoding_search
      get '/countries' => 'api#countries'
      get '/competition_series/:id' => 'api#competition_series'
      resources :competitions, only: [:index, :show] do
        get '/wcif' => 'competitions#show_wcif'
        get '/wcif/public' => 'competitions#show_wcif_public'
        get '/results' => 'competitions#results', as: :results
        get '/results/:event_id' => 'competitions#event_results', as: :event_results
        get '/competitors' => 'competitions#competitors'
        get '/registrations' => 'competitions#registrations'
        get '/schedule' => 'competitions#schedule'
        get '/scrambles' => 'competitions#scrambles', as: :scrambles
        get '/scrambles/:event_id' => 'competitions#event_scrambles', as: :event_scrambles
        get '/psych-sheet/:event_id' => 'competitions#event_psych_sheet', as: :event_psych_sheet
        patch '/wcif' => 'competitions#update_wcif', as: :update_wcif
      end
      get '/records' => "api#records"

      scope 'user_roles' do
        get '/user/:user_id' => 'user_roles#index_for_user', as: :index_for_user
        get '/group/:group_id' => 'user_roles#index_for_group', as: :index_for_group
        get '/group-type/:group_type' => 'user_roles#index_for_group_type', as: :index_for_group_type
        get '/search' => 'user_roles#search', as: :user_roles_search
      end
      resources :user_roles, only: [:create, :show, :update, :destroy]
      resources :user_groups, only: [:index, :create, :update]
      namespace :wrt do
        resources :persons, only: [:update, :destroy] do
          put '/reset_claim_count' => 'persons#reset_claim_count', as: :reset_claim_count
        end
      end
      namespace :wfc do
        resources :xero_users, only: [:index, :create]
        resources :dues_redirects, only: [:index, :create, :destroy]
      end
    end
  end
end
