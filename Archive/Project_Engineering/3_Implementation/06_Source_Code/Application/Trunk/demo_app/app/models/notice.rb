require 'lib/custom_exception.rb'

class Notice < ActiveRecord::Base
  # do not use model name in to_json output
  self.include_root_in_json = false  
  
  # associations
  has_many :notice_details
  has_many :notice_relationships
  has_many :notice_acknowledges
  
  belongs_to :job
  accepts_nested_attributes_for :notice_details
  accepts_nested_attributes_for :notice_relationships
  
  validates_uniqueness_of  :notice_id, :scope =>[:job_id, :notice_type],  :message => 'message.msg225'
  
  # parameter code
  TYPE_PARAMETER = 'NOTY'
  NCR = 'NCR'
  IMR = 'IMR'
  
  # mapping...
  MAP = {
    "Project Number" => "job_id",
    "NCR report number" => "notice_id",
    "Designation" => "designation",
    "Purchase Order n°" => "order_id",
    "Specification n°" => "specification_id",
    "Specification n° Revision" => "specification_revision",
    "Supervisor Name" => "supervisor",
    "Date" => "validity_from",
    "Classification" => "classification",
    "Problem Origin" => "problem_origin",
    "Extra Cost" => "extra_cost",
    "Currency" => "currency",
    "Number of Annex :" => "number_of_annexes"
  }
  
  NC_DIRECTORY = "data/nc/"
  
  after_create :create_nc_log
  after_update :update_nc_log
  
  # Get parameter code based notice type
  #
  # * *Args*    :
  # * *Returns* :
  #   - currencies list
  # 
  # *Written:* NghiPM
  # *Date:*    Jan 30, 2013
  #
  def self.types
    params = Parameter.joins(:parameter_type).where("parameter_types.type_id = ?", TYPE_PARAMETER)
    hash = {}
    params.each {|i| hash[i[:parameter_id]] = i[:id]}
    return hash
  end
  
  # This method is used to generation currency data.
  # Temporary solution for difference between inputed currency and currencies in Malis
  #
  # * *Args*    :
  # * *Returns* :
  #   - currencies list
  # 
  # *Written:* LienPTB
  #
  # *Date:*    Jan 09, 2013
  #
  # *Modified:*
  #
  # *Date:*
  #
  def self.currencies
    hash = {
      1 => "AUD - Australia Dollar",
      2 => "BRL - Brazil Real",
      3 => "BGN - Bulgaria Lev",
      4 => "CAD - Canada Dollar",
      5 => "CNY - China Yuan Renminbi",
      6 => "HRK - Croatia Kuna",
      7 => "CZK - Czech Republic Koruna",
      8 => "DKK - Denmark Krone",
      9 => "EUR - Euro",
      10 => "HKD - Hong Kong Dollar",
      11 => "HUF - Hungary Forint",
      12 => "ISK - Iceland Krona",
      13 => "INR - India Rupee",
      14 => "IDR - Indonesia Rupiah",
      15 => "ILS - Israel Shekel",
      16 => "JPY - Japan Yen",
      17 => "KRW - Korea (South) Won",
      18 => "LVL - Latvia Lat",
      19 => "LTL - Lithuania Litas",
      20 => "MYR - Malaysia Ringgit",
      21 => "MXN - Mexico Peso",
      22 => "NZD - New Zealand Dollar",
      23 => "NOK - Norway Krone",
      24 => "PHP - Philippines Peso",
      25 => "PLN - Poland Zloty",
      26 => "RON - Romania New Le",
      27 => "RUB - Russia Ruble",
      28 => "SGD - Singapore Dollar",
      29 => "ZAR - South Africa Rand",
      30 => "SEK - Sweden Krona",
      31 => "CHF - Switzerland Franc",
      32 => "THB - Thailand Baht",
      33 => "TRY - Turkey Lira",
      34 => "GBP - United Kingdom Pound",
      35 => "USD - United States Dollar",
      36 => "VND - Vietnam Dong",
      37 => "PLN - Zloty polonais"
    }
    return hash.to_a
  end
  
  # This method is used to read a report having format.
  #
  # * *Args*    :
  #   - +file_name+ -> file path of report
  #   - +sheet_name+ -> name of sheet contain data
  #   - +header_index+ -> index of column contain header
  #   - +value_index+ -> index of column contain value
  # * *Returns* :
  #   - book instance
  #   - header array
  #   - value array
  # 
  # *Written:* LienPTB
  #
  # *Date:*    Jan 09, 2013
  #
  # *Modified:*
  #
  # *Date:*
  #
  def self.read_report(params)
    headers = []
    values = []
   
    file_name = params[:location] + params[:file_name] || 'data/J0496_NCR_010.xls'
    sheet_name = params[:sheet_name] || 'Output_data'
    
    Spreadsheet.client_encoding = 'UTF-8'
    book = Spreadsheet.open(file_name)
    
    sheet1 = book.worksheet(sheet_name)
    header_index = params[:header_index] || 0
    value_index = params[:value_index] || 1
    
    sheet1.each do |row|
      row.each_index do |i|
        val = ''
        if row[i].is_a?(Spreadsheet::Formula)
          val = row[i].value
        else
          val = row[i]
        end
        headers << val if i == header_index
        values << val if i == value_index
      end
    end
    
    return {
      :book => book,
      :headers => headers, 
      :values => values
    }
  end
  
  # This method is used to create file name of NC report
  #
  # * *Args*    :
  #   - +options+ -> {:no => <report number>, :type => NCR/IMPR, :job => <job instance>}
  # * *Returns* :
  #   - file name
  # 
  # *Written:* LienPTB
  #
  # *Date:*    Jan 29, 2012
  #
  # *Modified:*
  #
  # *Date:*
  #
  def self.create_file_name(options)
    job_id = options[:job].job_id
    
    return "J#{job_id}_#{options[:type].upcase}_#{options[:no]}.xls"
  end
  
  # This method is used to import NC report.
  # This will get NC report from LAN (if any) by execute Pierre script.
  # Extract information from "Output_Data" sheet as MAP above
  # Insert information to 3 tables: notices, notice_relationships, notice_acknowledges
  #
  # * *Args*    :
  #   - +options+ -> {:no => <report number>, :type => NCR/IMPR, :job_id => <job id>, :current_user}
  # * *Returns* :
  #   - insert to database
  # 
  # *Written:* LienPTB
  #
  # *Date:*    Jan 29, 2012
  #
  # *Modified:*
  #
  # *Date:*
  #
  def self.import(options)
    current_user = options[:current_user]
    options[:type] = Parameter.as_hash[options[:type_id].to_i].parameter_id
    job = Job.where(:id => options[:job_id]).first
    file_name = create_file_name(options.merge({:job => job}))
    
    # get file from LAN
    # get_file_from_LAN({:type => options[:type], :file_name => file_name})
    path = import_path
    
    # read and get content
    begin
      reader = read_report({:file_name => file_name, :location => path})
    rescue Exception => ex
      raise CustomException::OperationFailed, ex.message
    end
    
    # extract information
    notice = extract_info(reader, current_user, job)
    if notice["job_id"].delete("J") != job.job_id
      raise CustomException::OperationFailed, "Import from LAN: cannot import notice"
    end
    
    # add some information
    notice["job_id"] = job.id
    notice["notice_type"] = options[:type_id]
    notice["notice_details_attributes"] = [{
      :file_type => NoticeDetail::TYPE[options[:type]],
      :file_path => file_name
    }]

    no = Notice.new(notice)
    if !no.save
      return {
        :success => false,
        :msg => Toolkit::translate(no.errors)
       }
    end
    
    # move file from temporary directory to NC directory
    FileUtils.mv("#{path}#{file_name}", NC_DIRECTORY + file_name)
    
    # TODO
    # Scan all annexes and store its with same directory + add record to table notice_details
    
    return {:success => true}
  end
  
  # This method is used to get NC report from LAN (if any) by execute Pierre script.
  #
  # * *Args*    :
  #   - +options+ -> {:type => NCR/IMPR, :file_name => <file name>}
  # * *Returns* :
  #   - raise error if any
  # 
  # *Written:* LienPTB
  #
  # *Date:*    Jan 29, 2012
  #
  # *Modified:*
  #
  # *Date:*
  #
  def self.get_file_from_LAN(options)
    str = "getfile  -t #{options[:type]}  #{options[:file_name]}   /tmp/"
    code = `str`
    case code
      when 1
        raise CustomException::OperationFailed, "Import from LAN: invalid arguments"
      when 2
        raise CustomException::OperationFailed, "Import from LAN: source file not found"
      when 3
        raise CustomException::OperationFailed, "Import from LAN: cannot create destination file"
      when 9
        raise CustomException::OperationFailed, "Import from LAN: error"
    end
  end
  
  # This method is used to extract information from file content.
  #
  # * *Args*    :
  #   - +headers+ -> array of headers field
  #   - +values+ -> array of values field (corresponding)
  #   - +current_user+ -> current user
  # * *Returns* :
  #   - notice object
  # 
  # *Written:* LienPTB
  #
  # *Date:*    Jan 29, 2012
  #
  # *Modified:*
  #
  # *Date:*
  #
  def self.extract_info(reader, current_user, job)
    headers = reader[:headers]
    values = reader[:values]
    obj = {}
    
    classifications = Parameter.joins("left join parameter_types t on t.id = parameter_type_id").where("t.type_id = ?", PARAM["notice.classification"]).select("parameters.id, parameter_id").index_by(&:parameter_id)
    
    origins = Parameter.joins("left join parameter_types t on t.id = parameter_type_id").where("t.type_id = ?", PARAM["notice.origin"]).select("parameters.id, parameter_id").index_by(&:parameter_id)
    
    parts = []
    drawing = []
    headers.each_index do |i|
      header = headers[i]
      value = values[i]
      h = MAP[header]
      
      # normal attributes
      if h
        obj[h] = value if !value.blank? && value != "NA"
        next
      end
      
      # list of parts
      if /^[pP]art number(\s)*(\d)*$/.match(header) && !value.blank? && value != 'NA'
        parts << job.job_id + ' ' + value.insert(6, ' ')
      end
      
      # list of drawings
      if /^[dD]rawing(\s)*(\d)*$/.match(header) && !value.blank? && value != 'NA'
        tmp = header.split(" ")
        drawing[tmp[1].to_i - 1] = {
          :pattern => value
        }
      end
      
      # Drawing Revision
      if /^[dD]rawing(\s)*(\d)*(\s)*-(\s)*[rR]evision$/.match(header) && !value.blank? && value != 'NA'
        tmp = header.split(" ")
        drawing[tmp[1].to_i - 1][:drawing_revision] = value
      end
    end
    
    if !obj["order_id"].blank?
      order = Order.where(:order_id => job.job_id + '/' + obj["order_id"]).first
      obj["order_id"] = order.id if order
    end
    
    if !obj["specification_id"].blank?
      spec = Drawing.where(:drawing_id => job.job_id + ' ' + obj["specification_id"]).first
      obj["specification_revision"] = "" if !spec
    end
    
    obj["classification"] = classifications[obj["classification"].to_i.to_s].id
    obj["problem_origin"] = origins[obj["problem_origin"].to_i.to_s].id
    
    obj["notice_relationships_attributes"] = drawing
    obj["parts"] = parts.join(";")
    
    obj["validity_from"] = reader[:book].convert_date(obj["validity_from"])
    obj["created_at"] = obj["updated_at"] = Time.now
    obj["created_by"] = obj["updated_by"] = current_user.user_id
    
    return obj
  end

  # Mark an NC as disabled
  #
  # * *Returns* :
  #   - true/false
  # * *Raises* :
  #   - +ArgumentError+ -> if any value is nil or negative
  #
  # Written by:: Nghi Pham
  # Date::       Jan 28, 2013
  #
  def disable(user)
    self.update_attributes(:status => false, :validity_to => Time.now, :updated_by => user)
    log_disable_operation(user)
  end
  
  # Load data for some combobox in Job Notice Details
  #
  # * *Returns* :
  # * *Raises* :
  #
  # Written by:: LienPTB
  # Date::       Jan 28, 2013
  #
  def self.load_base_param(x)
    if x["id"] == 'currency'
      return Notice.currencies
    end
    
    if ["notice.classification", "notice.origin"].include?(x["code"])
      return Parameter.get_parameter_only_description(PARAM[x['code']])
    end
    
    return Parameter.get_parameter(PARAM[x['code']])
  end
  
  # Load information of notice
  #
  # * *Args*    :
  #   - +id+ -> id of notice
  # * *Returns* :
  #   - array of hash
  # 
  # *Written:* LienPTB
  #
  # *Date:*    Jan 18, 2013
  #
  # *Modified:*
  #
  # *Date:*
  #
  def self.load_one(id, drawing_id)    
    no = Notice.where(:id => id).joins("left join jobs on jobs.id = notices.job_id left join orders on notices.order_id = orders.id").includes([:notice_details, :notice_relationships]).select("notices.*, jobs.job_id as job_name, orders.order_id as order_name, orders.puco as puco").first
    
    if !no
      return {:success => false}
    end
    
    # General information
    data = no.attributes
    data["job_id"] = no.job_name
    data["created_on"] = no.created_by + " on " + no.created_at.to_std
    data["updated_on"] = no.updated_by + " on " + no.updated_at.to_std
    data["validity_from"] = no.validity_from.to_std
    data["validity_to"] = no.validity_to.to_std
    
    if !no.order_name.blank?
      tmp = no.order_name.split("/")
      data["order"] = tmp[2]
    end
    
    # Drawing/Pattern list
    tmp = []
    no.notice_relationships.each do |x|
      t = x.pattern
      t += "/" + x.drawing_revision if !x.drawing_revision.blank?
      tmp << t
    end
    data[:drawing_id] = tmp.join(", ")
    
    # Details list
    d = {}
    tmp = []
    num = 0
    no.notice_details.each do |x|
      if x.file_type == NoticeDetail::TYPE["NCR"]
        d[:detail] = x.file_path 
        next
      end
      
      num += 1
      tmp << {
        :id => num,
        :name => x.file_path
      }
    end
    d[:annexes] = {
      :rows => tmp,
      :count => tmp.size
    }
    data[:details] = d
    
    # Logs
    key = Parameter.as_hash[no.notice_type].parameter_id + " " + no.notice_id
    logs = Transaction.where(:job_id => no.job_id, :key => key).joins("left join parameters on parameters.id = operations_on_drawings.operation_id").select("parameters.parameter_id as operation, operations_on_drawings.*")
    tmp = []
    logs.each do |x|
      tmp << {
        :tr => x.operation,
        :date => x.created_at.to_std,
        :author => x.created_by,
        :description => x.description
      }
    end
    
    data[:logs] = {
      :rows => tmp,
      :count => tmp.size
    }
    
    if !drawing_id.blank?
      d = NoticeAcknowledge.where(:notice_id => no.id, :drawing_id => drawing_id).first
      data["ack_on"] = d.ack_by.to_s + " on " + d.ack_date.to_std if d
    end
    
    return data
  end
  
  # Get all associated drawings (in a combined string)
  #
  # * *Returns* :
  #   - string of all associated drawings
  # * *Raises* :
  #
  # Written by:: NghiPM
  # Date::       Jan 30, 2013
  #
  def drawings
    return self.notice_relationships.map {|e| (e.pattern + "/" + e.drawing_revision.to_s).gsub(/\/$/, '') }.join(", ")
  end
  
  # Update notice information
  #
  # * *Args*    :
  #   - +id+ -> id of notice
  #   - +params+ -> information of notice
  #   - +current_user+ -> current user
  # * *Returns* :
  #   - array of hash
  # 
  # *Written:* LienPTB
  #
  # *Date:*    Jan 30, 2013
  #
  # *Modified:*
  #
  # *Date:*
  #
  def self.update_nc(params, current_user)
    no = Notice.where(:id => params[:id]).joins("left join jobs on jobs.id = notices.job_id").select("notices.*, jobs.job_id as job_name").includes([:notice_relationships]).first
    if !no
      raise CustomException::OperationFailed, I18n.t("message.msg4038")
    end
    
    params.delete("controller")
    params.delete("action")
    
    # Pre-processing: Drawing relationship, Specification, Order
    drawings = params.delete('drawing_id')
    data = []
    drawings.split(",").each do |x|
      t = x.split("/")
      data << {
        :pattern => t[0],
        :drawing_revision => t[1]
      }
    end
    params[:notice_relationships_attributes] = data
    
    spec = params.delete('specification')
    d = Drawing.where(:drawing_id => no.job_name + " " + spec).first
    params[:specification_id] = spec if d
    params[:specification_revision] = "" if !d
    
    order = params.delete("order").split(" - ")[0]
    puco = params.delete("puco")
    order_id = Order.create_order_id(no.job_name, puco, order)
    o = Order.where(:order_id => order_id).first
    params[:order_id] = o.id if o
    
    params[:updated_at] = Time.now
    params[:updated_by] = current_user.user_id
    
    no.notice_relationships.destroy_all
    if !no.update_attributes(params)
      return {
        :success => false,
        :msg => Toolkit::translate(no.errors)
      }
    end
    
    return {:success => true}
  end
  
  # Create a log when a nc is created
  #
  # * *Returns* :
  # * *Raises* :
  #
  # Written by:: LienPTB
  # Date::       Jan 28, 2013
  #
  private
  def create_nc_log
    type = Parameter.as_hash[self.notice_type].parameter_id
    
    params = {
      :operation_id => Transactions::CREATE_NOTICE,
      :job_id => self.job_id,
      :drawing_id => '',
      :part_id => '',
      :quantity => '',
      :reason => '',
      :description => 'Create Job Notice',
      :user => self.created_by,
      :revision => '',
      :key => type + " " + self.notice_id
    }
    Transaction.record_transaction(params)
  end
  
  # Create a log when a nc is updated
  #
  # * *Returns* :
  # * *Raises* :
  #
  # Written by:: LienPTB
  # Date::       Jan 28, 2013
  #
  def update_nc_log
    type = Parameter.as_hash[self.notice_type].parameter_id
    
    params = {
      :operation_id => Transactions::MODIFY_NOTICE,
      :job_id => self.job_id,
      :drawing_id => '',
      :part_id => '',
      :quantity => '',
      :reason => '',
      :description => 'Modify Job Notice',
      :user => self.updated_by,
      :revision => '',
      :key => type + " " + self.notice_id
    }
    Transaction.record_transaction(params)
  end
  
  # Log the NOTICE DISABLE operation
  #
  # * *Args*    :
  #   - +user+ -> by whom the operation is done
  # 
  # *Written:* NghiPM
  # *Date:*    Jan 30, 2012
  #
  def log_disable_operation(user)
    type = Parameter.as_hash[self.notice_type].parameter_id
    Transaction.record_transaction(
      :operation_id => Transactions::DISABLE_NOTICE,
      :job_id => self.job_id,
      :drawing_id => '',
      :part_id => '',
      :quantity => '',
      :reason => '',
      :description => 'Disable Job Notice',
      :user => user,
      :revision => '',
      :key => "#{type} #{self.notice_id}"
    )
  end
  
  # Get path for importing NC
  #
  # * *Args*    :
  # 
  # *Written:* LienPTB
  # *Date:*    Jan 31, 2012
  #
  def self.import_path
    loc = Parameter.joins("left join parameter_types t on t.id = parameter_type_id left join (select * from parameter_descriptions where language_id = #{DEFAULT_LANG}) as descs on descs.parameter_id = parameters.id").where("t.type_id = ? and parameters.parameter_id = ?", 'LANL', 'NCR').select("descs.description").first
    
    path = ""
    path = loc.description if loc
    
    path
  end
end
