# == Application Controller
# 
# Author:: Lien Pham-Thi-Bich
# Created Date::
# Updated Date::  
# Updated By::
# 
# 
# == Summary
# 
# This class holds common methods that is inherited in other controllers
# - Common methods
# - Identify Customize Exceptions
#

require "authenticated_system"
require "custom_exception"
require 'lib/stage.rb'
class ApplicationController < ActionController::Base
  # protect_from_forgery
  include AuthenticatedSystem
  
  # set locale if any
  before_filter :set_locale
 
  # This method get the symbol of language that the website/document should be displayed
  # then set the locale setting
  #
  # * *Args*    :
  #   - +locale+ -> symbol of language. If null, use default locale
  # * *Returns* :
  #   - set display language of website/document
  # 
  # *Written:* LienPTB
  #
  # *Date:*    Jan 09, 2012
  #
  # *Modified:*
  #
  # *Date:*
  #
  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

  # This method define the way that application handle the Exception
  # - Return response with status = 500 with exception message attached
  # - Write to console the message and trace of the exception
  #
  # Written by:: LienPTB
  # Date::       Jan 09, 2012
  #
  rescue_from Exception do |exception|
    render :json => {:msg => exception.message}, :status => 500
    puts "\n"
    puts exception.message
    puts exception.backtrace.delete_if{|i| !i.index(Rails.root)}
    puts "\n\n"
  end
  
  # This method define an custom exception used for normal page (non-Ajax request)
  # redirect user to a notification file
  # 
  # *Name*:: AccessDenied
  # *Template File*:: error/access_denied
  # 
  # Written by:: LienPTB
  # Date::       Jan 09, 2012
  #
  rescue_from CustomException::AccessDenied do |exception| 
    render :template => "error/access_denied", :layout => true, :locals => {:msg => exception.message}
  end

  # This method define an custom exception used for Ajax response for such action as deleting/editing
  # 
  # *Name*:: PermissionDenied
  # *Status*:: 1
  # 
  # Written by:: LienPTB
  # Date::       Jan 09, 2012
  #
  rescue_from CustomException::PermissionDenied do |exception|
    render :json => {:success => false, :status => 1, :msg => exception.message}
  end

  # This method define an custom exception used for 
  # render empty data in case that the job doesn't exist. 
  # 
  # *Name*:: NotExistJob
  # *Status*:: 1
  # 
  # Written by:: LienPTB
  # Date::       Jan 21, 2012
  #
  rescue_from CustomException::NotExistJob do |exception|
    @group_data = {
      :rows => [],
      :count => 0,
      :msg => exception.message
    }      
    @paging = WillPaginate::Collection.create(1, PER_PAGE, 0) do |pager|
      pager.replace([])
    end
    render :partial => "shared/data_and_paging_save_remind"
  end
  
  # This method define an custom exception used for Ajax response 
  # for db conflict (detected by optimistic lock)
  # 
  # *Name*:: StaleObjectError
  # *Status*:: 1
  # *Message*:: Someone else has already changed the record. Please reload the page and try again
  # 
  # Written by:: LienPTB
  # Date::       Jan 09, 2012
  #
  rescue_from ActiveRecord::StaleObjectError do |exception|
    render :json => {:success => false, :status => 1, :msg => I18n.t('message.msg49')}
  end

  # This method define an custom exception used for Ajax response for such action as deleting/editing
  # 
  # *Name*:: OperationFailed
  # *Status*:: 1
  # 
  # Written by:: LienPTB
  # Date::       Jan 09, 2012
  #
  rescue_from CustomException::OperationFailed do |exception|
    render :json => {:success => false, :status => 1, :msg => exception.message}
  end

  # This method define an custom exception used for 
  # Ajax response for such action as deleting/editing (validating only)
  # 
  # *Name*:: ValidationFailed
  # *Status*:: 1
  # 
  # Written by:: LienPTB
  # Date::       Jan 09, 2012
  # 
  rescue_from CustomException::ValidationFailed do |exception|
    render :json => {:success => false, :status => 2, :msg => exception.message}
  end

  # This method define an custom exception used for 
  # generating empty PDF document using Prawn
  # 
  # *Name*:: EmptyTable
  # *Status*:: 1
  # *Message*:: No data to export
  # 
  # Written by:: LienPTB
  # Date::       Jan 09, 2012
  # 
  rescue_from Prawn::Errors::EmptyTable do |exception|
    render :json => {:success => false, :status => 1, :msg => I18n.t('message.msg513')}
  end

  # Download a file from server
  #
  # * *Args*    :
  #   - +file_name+ -> the name/path of the file
  # * *Returns* :
  #   - send the file to user
  # * *Raises* :
  #   - +CustomException+ -> if any exception occurs. Ex: the file doesn't exist, I/O error, ...
  #
  # *Written:* LienPTB
  #
  # *Date:*    Mar 25, 2011
  #
  # *Modified:*
  #
  # *Date:*
  #
  def download_file
    file_name = "data/" + params[:file_name]

    begin
      send_file file_name
    rescue Exception => ex
      raise CustomException, ex.message
    end
  end

  # Download a edition file (PDF/Excel) from server. 
  # This method will use id of input record then get it's note as path of the edition file
  #
  # * *Args*    :
  #   - +input_id+ -> id of input record used to track edition progress
  # * *Returns* :
  #   - send the file to user
  # * *Raises* :
  #   - +CustomException+ -> if any exception occurs. 
  # Ex: the input record dosn't exits, the file doesn't exist, I/O error, ...
  #
  # *Written:* LienPTB
  #
  # *Date:*    Sep 14, 2012
  #
  # *Modified:*
  #
  # *Date:*
  #
  def download_edition_file
    input_id = params[:input_id]
    begin
      input = Input.find input_id
      file_name = "data/" + input.note
      
      send_file file_name
    rescue Exception => ex
      raise CustomException, ex.message
    end
  end
  
  # Download sample file of an import process.
  # This method will take the model name and return corresponding sample file.
  # All sample files will be stored in public/sample_file/
  #
  # * *Args*    :
  #   - +model+ -> name of the model will be imported
  # * *Returns* :
  #   - send the file to user
  # * *Raises* :
  #   - +CustomException+ -> if any exception occurs. 
  # Ex: the file doesn't exist, I/O error, ...
  #
  # *Written:* DuongDN
  #
  # *Date:*    Nov 8, 2012
  #
  # *Modified:*
  #
  # *Date:*
  #
  def download_sample
    if params[:model] == 'customer_item'
      params[:model] = 'contract_item'
    end
    file_name = "public/sample_file/" + params[:model] + ".zip"
    
    begin
      send_file file_name
    rescue Exception => ex
      raise CustomException, ex.message
    end
  end

  # This method is used to get content of a file.
  #
  # * *Args*    :
  #   - +file_name+ -> the name/path of the file
  # * *Returns* :
  #   - {:success => false} if failure
  #   - {:success => true, :content => <file-content>} if success
  #
  # *Written:* DuongDN
  #
  # *Date:*    Nov 8, 2012
  #
  # *Modified:*
  #
  # *Date:*
  #
  def get_detail_of_file
    result = {:success => true}
    begin
      file_name = "data/" + params[:file_name]
      result[:content] = File.read(file_name)
    rescue
      result = {:success => false}
    end     
    render :text => result.to_json
  end
  
  # This method is used to get progress of an exporting process. 
  # It will find model name based on controller name. 
  # Then find the latest input of this model with current user. 
  # And return all attributes of this input
  # 
  # * *Args*    :
  #   - +controller+ -> the controller name
  # * *Returns* :
  #   - {:success => false} if failure
  #   - {:success => true, <input attributes, ex: percentage: <>, id: <>, ...>} if success
  #
  # *Written:* LienPTB
  #
  # *Date:*    June 23, 2012
  #
  # *Modified:*
  #
  # *Date:*
  #
  
  def get_progress_exporting    
    controller =  params["controller"]   
    map_controler_model = {
      "currencies" => "currency",
      "items" => "part",
      "assemblies" => "assembly",
      "bouki_parameters" => "parameter_type",
      "rfqs" => ['rfq','material_list','view_rfm_list']
    }
    model =  map_controler_model[controller]
    model = controller[0..-2] if !model
    begin
      result = Input.get_progress_export(@current_user.id, model)
      render :text => result.to_json
    rescue
    end
  end

  # This method is used to get progress of an exporting process. 
  # It will find model name based on controller name. 
  # Then find the latest input of this model with current user. 
  # And set the status of this input is KILLED
  # 
  # * *Args*    :
  #   - +controller+ -> the controller name
  # * *Returns* :
  #   - {:success => false} if failure
  #   - {:success => true} if success
  #
  # *Written:* LienPTB
  #
  # *Date:*    June 15, 2012
  #
  # *Modified:*
  #
  # *Date:*
  #
  def cancel_export
    # get current user's running process
    controller =  params["controller"]
    map_controler_model = {
      "currencies" => "currency",
      "items" => "part",
      "assemblies" => "assembly",
      "bouki_parameters" => "parameter_type",
      "rfqs" => ['rfq','material_list','view_rfm_list']
    }
    model =  map_controler_model[controller]
    model = controller[0..-2] if !model

    process = Input.find :first, :conditions => ["created_by = ? and source = '#{Input::EXPORT_TO_PDF}' and status not in (-1, 7) and extra_data in (?)", @current_user.id,model], :order => "id DESC"
    process.set_status(Input::KILLED) # mark as KILLED, the import daemon will not proceed when status is KILLED
    render :text => {:success => true}.to_json
  end

  # This method is used to get progress of an process. 
  # It will find model name based on its id
  # and return percentage of this input
  # 
  # * *Args*    :
  #   - +id+ -> id of the input record
  # * *Returns* :
  #   - -1 if failure
  #   - <percentage> if success
  #
  # *Written:* DuongDN
  #
  # *Date:*    Aug 22, 2012
  #
  # *Modified:*
  #
  # *Date:*
  #
  def get_percent_of_input
    input_id = params[:id]
    begin
      input = Input.find(:first,:conditions => ['id = ? and status <> ?', input_id,Input::KILLED])
      value = input.percentage  
    rescue 
      value = -1
    end
    render :text => value
  end

  # This method is used to kill an process. 
  # It will find model name based on its id
  # and set its status to KILLED
  # 
  # * *Args*    :
  #   - +id+ -> id of the input record
  # * *Returns* :
  #   - {:success => false} if failure or exception
  #   - {:success => true} if success
  #
  # *Written:* DuongDN
  #
  # *Date:*    Aug 22, 2012
  #
  # *Modified:*
  #
  # *Date:*
  #
  def set_input_process_status
    input_id = params[:id]
    return_data = {:success => true}
    begin
      input = Input.find input_id
      input.set_status(Input::KILLED)
    rescue
      return_data = {:success => false}
    end
    render :text => return_data.to_json
  end
end

