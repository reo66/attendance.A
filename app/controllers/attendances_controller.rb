class AttendancesController < ApplicationController
 
  before_action :set_user, only: [:edit_one_month]
  before_action :logged_in_user, only: [:update, :edit_one_month]
  before_action :admin_user, only: [:index,:destroy,:edit_basic_info]
  before_action :set_one_month, only: [:edit_one_month]

  UPDATE_ERROR_MSG = "勤怠登録に失敗しました。やり直してください。"


  # 残業申請お知らせモーダル
  
  def edit_overtime_notice
    @user = User.find(params[:user_id])
    # Attendanceテーブルから、indicater_check_superiorが申請中のもの、indicater_checkの上長名を取り出し、user_id,順と、worked_on順にし、group_byでuser_id毎にグループ分する
    @attendances = Attendance.where(indicater_check_superior: "申請中", indicater_check: @user.name).order(:user_id, :worked_on).group_by(&:user_id)
  end


# 残業申請お知らせモーダル更新
  def update_overtime_notice
    attendances_params.each do |id, item|
    item[:indicater_check_superior].present?
      if item[:change] == "1"
        if item[:indicater_reply] == "なし"
          flash[:success] = "申請を取り消しました"
        elsif  item[:indicater_reply] == "承認"
          flash[:success] = "申請を承認しました"
        elsif  item[:indicater_reply] == "否認"
          flash[:success] = "申請を否認しました"
        else
        end
      else 
        flash.now[:danger] = "変更にチェックがありません"
      end
    end  






  # # トランザクションを開始
  #   ActiveRecord::Base.transaction do 
  #     # oはovertime。「なし」「承認」「否認」を1〜3で定義
  #     o1 = 0
  #     o2 = 0
  #     o3 = 0
  #     attendances_params.each do |id, item|
  #       # itemの中のカラム、indicater_check_superiorが存在すれば
  #       if item[:indicater_check_superior].present?
  #         # itemの中のカラム、changeにチェックがある状態（チェックの有無は0or1で表現）かつ、itemの中のカラム、ndicater_replyが、なしor承認or否認だったら
  #         if (item[:change] == "1") && (item[:indicater_reply] == "なし" || item[:indicater_reply] == "承認" || item[:indicater_reply] == "否認")
  #         attendance = Attendance.find(id)
  #         # itemの中のカラム、indicater_replyの値が「なし」なら
  #           if item[:indicater_reply] == "なし" 
  #         # overtime１に１を足す
  #             o1 += 1
  #           #   userが申請した残業申請のカラムをnilで更新
  #           @user.overtime_params == nil
  #           attendance.update_attributes!(item)
  #           flash[:warning] = "#{user.name}の残業申請を取り消しました"
  #           redirect_to user_url(@user)  


  #         # itemの中のカラム、indicater_replyの値が「承認」なら
  #           elsif item[:indicater_reply] == "承認"
  #           # overtime2に１を足す
  #             o2 += 1

  #             flash[:success] = "残業申請を承認しました"
  #             attendance.update_attributes!(item)
  #             redirect_to user_url(@user)  

  #         # itemの中のカラム、indicater_replyの値が「否認」なら
  #           else item[:indicater_reply] == "否認"
  #         # overtime3に１を足す
  #             o3 += 1
  #             flash[:danger] = "残業申請を否認しました"
  #         attendance.update_attributes!(item)
  #         redirect_to user_url(@user)  

  #           end
  #         end
  #       end
      end

      # トランザクションによるエラーの分岐
    rescue ActiveRecord::RecordInvalid 
    flash[:danger] = "無効な入力データがあった為、更新をキャンセルしました。"
    # お知らせモーダルにリダイレクト
    redirect_to edit_overtime_notice_user_attendance_url(@user,@overtime)
    end 
  end




# 残業申請モーダル
  def edit_overtime_request
    @user = User.find(params[:user_id])
    @attendance = Attendance.find(params[:id])
    # ユーザーテーブルから、superiorがtrueになっているもので自分のuser_id以外のものを@superiorに代入
    @superior = User.where(superior: true).where.not( id: current_user.id )
  end

  
  def update_overtime_request
    @user = User.find(params[:user_id])
    @attendance = Attendance.find(params[:id])
    if @attendance.update_attributes(overtime_params)
      flash[:success] = "残業申請を受け付けました"
      redirect_to user_url(@user)
    end  
  end



  def update
    @user = User.find(params[:user_id])
    @attendance = Attendance.find(params[:id])
    # 出勤時間が未登録であることを判定します。
    if @attendance.started_at.nil?
      if @attendance.update_attributes(started_at: Time.current.change(sec: 0))
        flash[:info] = "おはようございます！"
      else
        flash[:danger] = UPDATE_ERROR_MSG
      end
    elsif @attendance.finished_at.nil?
      if @attendance.update_attributes(finished_at: Time.current.change(sec: 0))
        flash[:info] = "お疲れ様でした。"
      else
        flash[:danger] = UPDATE_ERROR_MSG
      end
    end
    redirect_to @user
  end

  def edit_one_month
  end 

  def update_one_month
    ActiveRecord::Base.transaction do # トランザクションを開始します。
      attendances_params.each do |id, item|
        attendance = Attendance.find(id)
        attendance.update_attributes!(item)
      end
    end
    flash[:success] = "1ヶ月分の勤怠情報を更新しました。"
    redirect_to user_url(date: params[:date])
  rescue ActiveRecord::RecordInvalid # トランザクションによるエラーの分岐です。
    flash[:danger] = "無効な入力データがあった為、更新をキャンセルしました。"
    redirect_to attendances_edit_one_month_user_url(date: params[:date])
  end


  
  
  


private
    # 1ヶ月分の勤怠情報を扱います。
    def attendances_params
      params.require(:user).permit(attendances: [:started_at, :finished_at, :note])[:attendances]
    end


    # 残業申請モーダルの情報
    def overtime_params
      # attendanceテーブルの（残業終了予定時間,翌日、残業内容、指示者確認（どの上長か）、指示者確認（申請かどうか））
      params.require(:attendance).permit(:overtime_finished_at, :tomorrow, :overtime_work,:indicater_check,:indicater_check_superior)
    end

    # 残業申請お知らせモーダルの情報
    def overtime_notice_params
      # attendanceテーブルの（指示者確認,変更、勤怠を確認する）
      params.require(:attendance).permit(:indicater_reply, :change, :verification, :indicater_check_superior)
    end


    


  end   
