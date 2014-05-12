module Spree
  module Admin
    class GiftCardsController < Spree::Admin::BaseController
      before_filter :load_and_authorize_resource, except: :index
      before_filter :copy_original_value, only: [:create, :update]
      before_filter :handle_restricted_user, only: [:create, :update]

      def update
        if @gift_card.update_attributes(gift_card_params)
          flash[:success] = flash_message_for(@gift_card, :successfully_updated)
          redirect_to admin_gift_cards_path
        else
          render :edit
        end
      end

      def index
        consolidate_search_parameters

        @search = Spree::GiftCard.accessible_by(current_ability, action_name).
          ransack(params[:q])
        @gift_cards = @search.result.
          page(params[:page]).
          per(Spree::Config[:orders_per_page])
      end

      def create
        @gift_card = Spree::GiftCard.create(gift_card_params)

        if @gift_card.persisted?
          Spree::GiftCardMailer.gift_card_issued(@gift_card).deliver
          flash[:success] = Spree.t(:successfully_created_gift_card)
          redirect_to admin_gift_cards_path
        else
          render :new
        end
      end

      def destroy
        if @gift_card.destroy
          flash[:success] = Spree.t(:gift_card_destroyed)
          redirect_to admin_gift_cards_path
        else
          redirect_to admin_gift_cards_path
        end
      end

      def void
        if @gift_card.current_value > 0 && @gift_card.update(current_value: 0)
          flash[:success] = Spree.t(:gift_card_voided)
          redirect_to admin_gift_cards_path
        else
          flash[:error] = Spree.t(:gift_card_void_failure)
          redirect_to admin_gift_cards_path
        end
      end

      def restore
        if @gift_card.current_value == 0 && @gift_card.update(current_value: @gift_card.original_value)
          flash[:success] = Spree.t(:gift_card_restored)
          redirect_to admin_gift_cards_path
        else
          flash[:error] = Spree.t(:gift_card_restore_failure)
          redirect_to admin_gift_cards_path
        end
      end

      def show
        if @gift_card
          @adjustments = Spree::Adjustment.scoped.gift_card.where(source_id: @gift_card.id)
        end
      end

      private

      def load_and_authorize_resource
        if params[:id]
          @gift_card = Spree::GiftCard.find(params[:id])
        else
          @gift_card = Spree::GiftCard.new
        end

        authorize! action_name, @gift_card
      end

      def copy_original_value
        params[:gift_card][:current_value] = params[:gift_card][:original_value]
      end

      def handle_restricted_user
        if params[:restrict_user]
          user = Spree.user_class.find_by email: params[:gift_card][:email]

          if user
            params[:gift_card][:user_id] = user.id
            return true
          else
            @gift_card.attributes = gift_card_params
            @gift_card.errors.add(:email, Spree.t(:could_not_find_user))
            render (@gift_card.new_record? ? :new : :edit)
            return false
          end
        end
      end

      def consolidate_search_parameters
        if params[:sort_by] && params[:sort_direction]
          params[:q] ||= {}
          params[:q][:s] = "#{params[:sort_by]} #{params[:sort_direction]}"
        end
      end

      def gift_card_params
        params[:gift_card].permit(:q, :email, :user_id, :current_value, :original_value, :name, :note, :value, :variant_id, :expiration_date)
      end
    end
  end
end
