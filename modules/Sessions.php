<?php

class Sessions extends Application {
	function new($get, $post, $files) {
		$_SESSION['user_id'] && Utilities::redirect_to('home');
		$this->_form($get, $post, $files);
	}

	function create($get, $post, $files) {
		if (!empty($post['login']) && !empty($post['password'])) {
			$stmt = $this->_db->prepare('SELECT id, "hash" FROM users WHERE (id::text = ? OR email = ?) AND resign IS NULL');
			$stmt->execute([$post['login'], $post['login']]);
			$user = $stmt->fetchObject();
			if ($user && password_verify($post['password'], $user->hash)) {
				$_SESSION['user_id'] = $user->id;
				$this->_db->query("UPDATE users SET last_login = '" . $this->_now->format('Y-m-d H:i:s') . "' WHERE id = $user->id");
				Utilities::redirect_to('home');
			}
		}
		$this->_alert = ['type' => 'danger', 'message' => _('incorrect email and / or password, please try again')];
		$this->_form($get, $post, $files);
	}

	function destroy($get, $post, $files) {
		$_SESSION = ['locale' => $_SESSION['locale']];
		session_destroy();
		Utilities::redirect_to('home');
	}

	private function _form($get, $post, $files) {
		$this->_content .=
		$this->_get_form_notification() .
		'<h1>&nbsp;</h1>
		<form action="' . Utilities::link_to('sessions/create') . '" method="POST" role="form" class="form-horizontal">
			<fieldset>
				<legend class="text-center"><i class="fa fa-sign-in">&nbsp;</i> ' . _('Login') . '</legend>
				<div class="form-group">
					<label for="login" class="col-xs-6 col-md-4 control-label"><i class="fa fa-user">&nbsp;</i>&nbsp;' . _('ID / Email') . '</label>
					<div class="col-xs-6 col-md-4">
						<input id="login" name="login" type="text" value="' . $post['login'] . '" size="30" maxlength="30" class="form-control" placeholder="' . _('ID / Email') . '">
					</div>
				</div>
				<div class="form-group">
					<label for="password" class="col-xs-6 col-md-4 control-label"><i class="fa fa-key">&nbsp;</i>&nbsp;Password</label>
					<div class="col-xs-6 col-md-4">
						<input id="password" name="password" type="password" size="30" maxlength="30" class="form-control">
					</div>
				</div>
				<div class="form-group">
					<div class="col-xs-6 col-md-4">&nbsp;</div>
					<div class="col-xs-6 col-md-4">
						<button type="submit" class="btn btn-primary"><i class="fa fa-sign-in">&nbsp;</i> ' . _('Login') . '</button>
					</div>
				</div>
			</fieldset>
		</form>';
	}

	function show($get, $post, $files) {
		$user = $this->_current_user();
		$last_login = new DateTime($user->last_login);
		$id = str_repeat('0', 3 - strlen($user->id)) . $user->id;
		$this->_content .=
			$this->_get_form_notification() .
			"<table class=\"table table-striped table-hover table-condensed\">
				<tbody>
					<tr>
						<td class=\"text-right\" style=\"vertical-align:middle\">&nbsp;</td>
						<td><img src=\"/images/photos/" . (file_exists("images/photos/{$id}-sm.jpg") ? $id : 'anonymous') . "-md.jpg\" alt=\"$user->full_name\"></td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('ID') . "</td>
						<td>$id</td>
					</tr>
					<tr>
						<td class=\"text-right\" style=\"vertical-align:middle\">" . _('Name') . ' / ' . _('Alias') . "</td>
						<td>$user->full_name / $user->alias</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Place of Birth') . ' / ' . _('Date of Birth') . "</td>
						<td>$user->pob / " . ($user->dob ? $this->_date_formatter->format(new DateTime($user->dob)) : '-') . "</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Age') . "</td>
						<td>" . sprintf(ngettext('%d Year', '%d Years', $user->age), $user->age) . "</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('KTP') . ' / ' . _('SIM') . ' / ' . _('NISN') . "</td>
						<td>$user->ktp_sim</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Occupation') . "</td>
						<td>$user->occupation</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Address'). "</td>
						<td>$user->full_address</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Email') . "</td>
						<td>$user->email</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Mobile Phone') . "</td>
						<td>$user->phone</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Forbiscom ID') . "</td>
						<td>$user->forbiscom_id</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Join') . ' / ' . _('Permanent') . "</td>
						<td>" . $this->_period_formatter->format(new DateTime($user->join . '01')) . ' / ' . ($user->permanent ? $this->_period_formatter->format(new DateTime($user->permanent . '01')) : '-') . "</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Cash Status') . "</td>
						<td>$user->cash_status</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Role') . "</td>
						<td>$user->role</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Last Login') . "</td>
						<td>" . _('Date') . ' ' . $this->_date_formatter->format($last_login) . ' , ' . _('Hour') . ' ' . $last_login->format('H:i') . "</td>
					</tr>";
		if ($user->last_password_change) {
			$last_password_change = new DateTime($user->last_password_change);
			$this->_content .= "
					<tr>
						<td class=\"text-right\">" . _('Last Password Change') . "</td>
						<td>" . _('Date') . ' ' . $this->_date_formatter->format($last_password_change) . ' , ' . _('Hour') . ' ' . $last_password_change->format('H:i') . "</td>
					</tr>";
		}

		$this->_content .= "
				</tbody>
			</table>
			<div class=\"form-group\">" .
				($this->_allowed_to_access_link('Sessions', 'update') ? "<button type=\"button\" class=\"btn btn-primary\" onclick=\"location.href='" . Utilities::link_to('sessions/mine/edit') . "'\"><i class=\"fa fa-edit\">&nbsp;</i>" . _('Change Password') . "</button>" : '') .
			"</div>";
	}

	function edit($get, $post, $files) {
		$this->_password_form($get, $post, $files);
	}

	private function _password_form($get, $post, $files) {
		$this->_content .=
		$this->_get_form_notification() .
		'<h1>&nbsp;</h1>
		<form action="' . Utilities::link_to('sessions/mine/update') . '" method="POST" role="form" class="form-horizontal">
			<fieldset>
				<legend class="text-center"><h4><i class="fa fa-info-circle">&nbsp;</i> ' . _('To change your password, enter your current password and the new password') . '</h4></legend>
				<div class="form-group">
					<label for="password" class="col-xs-6 col-md-4 control-label">' . _('Current Password') . '</label>
					<div class="col-xs-6 col-md-4' . ($this->_error_messages['current_password'] ? ' has-error error' : '') . '">
						<input id="password" name="current_password" type="password" size="30" maxlength="30" class="form-control">
						<span class="help-block' . ($this->_error_messages['current_password'] ? ' text-danger' : '') . '">' . $this->_error_messages['current_password'] . '</span>
					</div>
				</div>
				<div class="form-group">
					<label for="password" class="col-xs-6 col-md-4 control-label">' . _('New Password') . '</label>
					<div class="col-xs-6 col-md-4' . ($this->_error_messages['new_password'] ? ' has-error error' : '') . '">
						<input id="password" name="new_password" type="password" size="30" maxlength="30" class="form-control">
						<span class="help-block' . ($this->_error_messages['new_password'] ? ' text-danger' : '') . '">' . $this->_error_messages['new_password'] . '</span>
					</div>
				</div>
				<div class="form-group">
					<label for="password" class="col-xs-6 col-md-4 control-label">' . _('Password Confirmation') . '</label>
					<div class="col-xs-6 col-md-4' . ($this->_error_messages['confirm_new_password'] ? ' has-error error' : '') . '">
						<input id="password" name="confirm_new_password" type="password" size="30" maxlength="30" class="form-control">
						<span class="help-block' . ($this->_error_messages['confirm_new_password'] ? ' text-danger' : '') . '">' . $this->_error_messages['confirm_new_password'] . '</span>
					</div>
				</div>
				<div class="form-group">
					<div class="col-xs-6 col-md-4">&nbsp;</div>
					<div class="col-xs-6 col-md-4">
						<button type="submit" class="btn btn-primary"><i class="fa fa-save">&nbsp;</i> ' . _('Save') . '</button>
					</div>
				</div>
			</fieldset>
		</form>';
	}

	function update($get, $post, $files) {
		$user = $this->_current_user();
		if (empty($post['new_password'])) {
			$this->_error_messages['new_password'] = _('is blank');
		} else if (!preg_match('/^(?=.*\d)(?=.*[a-z])(?=.*[A-Z]).{8,}$/', $post['new_password'])) {
			$this->_error_messages['new_password'] = _('minimum 8 characters; consists of small letters (a-z), capital letters (A-Z) and digits (0-9)');
		}
		if (empty($post['confirm_new_password'])) {
			$this->_error_messages['confirm_new_password'] = _('is blank');
		}
		if (!empty($post['new_password']) && !empty($post['confirm_new_password']) && $post['new_password'] <> $post['confirm_new_password']) {
			$this->_error_messages['confirm_new_password'] = _('must match the new password');
		}
		if (empty($post['current_password'])) {
			$this->_error_messages['current_password'] = _('is blank');
		} else if (!password_verify($post['current_password'], $user->hash)) {
			$this->_error_messages['current_password'] = _('is wrong');
		} else if (empty($this->_error_messages['new_password']) && empty($this->_error_messages['confirm_new_password'])) {
			if (password_verify($post['new_password'], $user->password)) {
				$this->_error_messages['new_password'] = _('you cannot reuse a previous password');
			} else {
				parent::_db_update('users', ['hash' => Utilities::encrypt_password($post['new_password'])
					, 'last_password_change' => $this->_now->format('Y-m-d H:i:s')
					, 'id' => $user->id]);
				$this->_db->exec('REFRESH MATERIALIZED VIEW mv_users');
				$this->_alert = ['type' => 'success', 'message' => _('Password changed successfully, please logout and login to apply the new password')];
				header('Location: /my-profile');
				exit;
			}
		}
		$this->_alert = ['type' => 'danger', 'message' => _('Password changed unsuccessfully')];
		$this->_password_form($get, $post, $files);
	}

	private function _current_user() {
		return $this->_db->query("SELECT * FROM mv_users WHERE id = '{$_SESSION['user_id']}'")->fetchObject();
	}
}