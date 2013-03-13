#=================================================================================
#  * Name: HelpsController
#  * Description: control helps managment feature
#  * Created by: PhucTV
#  * Date Created: Dec 26, 2012
#  * Last Modified: Dec 26, 2012
#  * Modified by: PhucTV
#=================================================================================
class HelpsController < ApplicationController
  #=================================================================================
  #  * Method name: create_additional
  #  * Input: current_user, params
  #  * Output:
  #  * Date created: Dec 26, 2012
  #  * Developer: PhucTV
  #  * Description: create new additional user's notice
  #=================================================================================
  def create_additional
    return_data = AdditionalNotice.create_additional(params)
    render :json => return_data
  end
  
  #=================================================================================
  #  * Method name: load_additional
  #  * Input: current_user, params
  #  * Output:
  #  * Date created: Dec 26, 2012
  #  * Developer: PhucTV
  #  * Description: load additional user's notice
  #=================================================================================
  def load_additional   
    return_data = AdditionalNotice.load_additional(params)
    render :json => return_data
  end
  
  #=================================================================================
  #  * Method name: update_additional
  #  * Input: current_user, params
  #  * Output:
  #  * Date created: Dec 26, 2012
  #  * Developer: PhucTV
  #  * Description: update additional user's notice
  #=================================================================================
  def update_additional
    return_data = AdditionalNotice.update_additional(params)
    render :json => return_data
  end
  
  #=================================================================================
  #  * Method name: enable_additional
  #  * Input: current_user, params
  #  * Output:
  #  * Date created: Dec 26, 2012
  #  * Developer: PhucTV
  #  * Description: enable additional user's notice
  #=================================================================================
  def enable_additional
    return_data = {}
    return_data[:success] = true
    add = AdditionalNotice.where(:id => params[:id].to_i).first
    if add
      add.update_attributes({:status => true})
    end
    render :json => return_data
  end
  
  #=================================================================================
  #  * Method name: disable_additional
  #  * Input: current_user, params
  #  * Output:
  #  * Date created: Dec 26, 2012
  #  * Developer: PhucTV
  #  * Description: disable additional user's notice
  #=================================================================================
  def disable_additional
    return_data = {}
    return_data[:success] = true
    add = AdditionalNotice.where(:id => params[:id].to_i).first
    if add
      add.update_attributes({:status => false})
    end
    render :json => return_data
  end
  
  #=================================================================================
  #  * Method name: delete_additional
  #  * Input: current_user, params
  #  * Output:
  #  * Date created: Dec 26, 2012
  #  * Developer: PhucTV
  #  * Description: delete additional user's notice
  #=================================================================================
  def delete_additional
    return_data = {}
    return_data[:success] = true
    add = AdditionalNotice.where(:id => params[:id].to_i).first
    if add
      # Begin Record transaction -- PhucTV
      param = {
        :operation_id => Transactions::DELETE_COMMENT,
        :job_id=> params[:job_id].to_i,
        :drawing_id => '',
        :part_id => '',
        :quantity => '',
        :reason => '',
        :description => '',
        :user => params[:current_user],
        :revision => '',
        :key => ''
      }
      Transaction.record_transaction(param)
      AdditionalNotice.destroy(params[:id].to_i)
    end
    render :json => return_data
  end
end
