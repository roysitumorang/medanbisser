<?php

use Ds\Map;

class Users extends Application {
	function __construct($db, $route) {
		parent::__construct($db, $route);
		!apcu_exists('users_order_fields') && apcu_add('users_order_fields', new Map(['Nama' => 'full_name', 'Umur' => 'age', 'Nomor ID' => 'id']));
		$this->_order_fields = apcu_fetch('users_order_fields');
	}

	function index($get, $post, $files) {
		parent::index($get, $post, $files);
		$params = [];
		if (!empty($get['q'])) {
			$q = '%' . $get['q'] . '%';
			$params = [$q, $q];
			$this->_query .= ' WHERE id::text LIKE ? OR LOWER(full_name) LIKE ?';
		}
		$this->_paginate($get, Utilities::link_to('users'), $params, 'id, full_name, age, "join", years, status, months_of_debt, debt, last_pay_period, paid');

		$this->_content .=
			"<h2 class=\"navbar-form navbar-left\"><i class=\"fa fa-group\">&nbsp;</i> " . ngettext('User', 'Users', 2) . "</h2>
			<form method=\"GET\" action=\"" . Utilities::link_to('users') . "\" class=\"navbar-form navbar-right\" role=\"search\" onsubmit=\"('" . _('ID / Name') . "'==$('[name=q]').val())&amp;&amp;$('[name=q]').val('')\">
				<input type=\"text\" name=\"q\" value=\"{$get['q']}\" class=\"form-control\" placeholder=\"" . _('ID / Name') . "\">
				<button type=\"submit\" class=\"btn btn-default\"><i class=\"fa fa-search\">&nbsp;</i> " . _('Search') . "</button>" .
				($this->_allowed_to_access_link('Users', 'new') ? '<a type="button" href="' . Utilities::link_to('users/new') . '" class="btn btn-default"><i class="fa fa-user-plus">&nbsp;</i> ' . _('New') . '</a>' : '') .
			"</form>
			<div class=\"clearfix\"></div>
			$this->_pagination
			<table class=\"table table-striped table-hover table-condensed\">
				<thead>
					<tr>
						<th class=\"text-center\">" . _('ID') . "</th>
						<th class=\"text-center\">" . _('Name') . "</th>
						<th class=\"text-center\">" . _('Age') . "</th>
						<th class=\"text-center\">" . _('Join Date') . "</th>
						<th class=\"text-center\">" . _('Years of Membership') . "</th>
						<th class=\"text-center\">" . _('Status') . "</th>
						<th class=\"text-center\">" . _('Cash Status') . "</th>
						<th class=\"text-center\">#</th>
					</tr>
				</thead>
				<tbody>";

		foreach ($this->_rows as $row) {
			$id = str_repeat('0', 3 - strlen($row->id)) . $row->id;
			$this->_content .= "
					<tr>
						<td class=\"text-center\">$id</td>
						<td class=\"text-nowrap\">$row->full_name</td>
						<td class=\"text-center\">$row->age</td>
						<td class=\"text-right\">" . ($row->join ? $this->_period_formatter->format(new DateTime($row->join . '01')) : '') . "</td>
						<td class=\"text-center\">$row->years</td>
						<td class=\"text-nowrap\">$row->status</td>
						<td class=\"text-right text-nowrap\">" . ($row->debt ? sprintf(_('Debt') . ' ' . ngettext('%d Month', '%d Months', $row->months_of_debt) . ' ' . _('Since %s / %s'), $row->months_of_debt, $this->_period_formatter->format(DateTime::createFromFormat('Ym', $row->last_pay_period ?: $row->join)->modify('+1 month')), number_format($row->debt)) : ($row->paid ? _('Paid') . ' ' . _('up to') . ' ' . $this->_period_formatter->format(DateTime::createFromFormat('Ym', $row->last_pay_period)) . ' / ' . number_format($row->paid) : '')) . "</td>
						<td><img src=\"/images/photos/" . (file_exists("images/photos/$id-sm.jpg") ? $id : 'anonymous') . "-sm.jpg\"></td>
						<td class=\"text-center\">
							<a type=\"button\" href=\"" . Utilities::link_to("users/$row->id") . "\" class=\"btn btn-info\"><i class=\"fa fa-angle-double-right\">&nbsp;</i> " . _('Show') . "</a>
						</td>
					</tr>";
		}

		$this->_content .=<<<CONTENT
				</tbody>
			</table>
			$this->_pagination
			<div class="clearfix"></div>
CONTENT;
	}

	function show($get, $post, $files) {
		$user = $this->_prepare_data();
		$id = str_repeat('0', 3 - strlen($user->id)) . $user->id;
		$dob = $user->dob ? $this->_date_formatter->format(new DateTime($user->dob)) : '-';
		$poj = $user->join ? $this->_period_formatter->format(new DateTime($user->join . '01')) : '-';
		$pop = $user->permanent ? $this->_period_formatter->format(new DateTime($user->permanent . '01')) : '-';
		$this->_content .=
			$this->_get_form_notification() .
			"<table class=\"table table-striped table-hover table-condensed\">
				<tbody>
					<tr>
						<td class=\"text-right\" style=\"vertical-align:middle\">&nbsp;</td>
						<td><img src=\"/images/photos/" . (file_exists("images/photos/$id-sm.jpg") ? $id : 'anonymous') . "-md.jpg\" alt=\"$user->full_name\"></td>
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
						<td>$user->pob / $dob</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Age'). "</td>
						<td>$user->age Tahun</td>
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
						<td class=\"text-right\">" . _('Address') . "</td>
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
						<td class=\"text-right\">" . _('Forbiscom User ID') . "</td>
						<td>$user->forbiscom_id</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Join') . ' / ' . _('Permanent') . "</td>
						<td>$poj / $pop</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . _('Cash Status') . "</td>
						<td>" . ($user->debt ? _('Debt') . ' ' . sprintf(ngettext('%d Month', '%d Months', $user->months_of_debt), $user->months_of_debt) . ' ' . sprintf(_('Since %s / %s'), $this->_period_formatter->format(DateTime::createFromFormat('Ym', $user->last_pay_period ?: $user->join)->modify('+1 month')), number_format($user->debt)) : _('Paid') . ' ' . _('up to') . ' ' . $this->_date_formatter->format(DateTime::createFromFormat('Ym', $user->last_pay_period)) . ' / ' . number_format($user->paid)) . "</td>
					</tr>
					<tr>
						<td class=\"text-right\">" . ngettext('Role', 'Roles', 1) . "</td>
						<td>$user->role</td>
					</tr>
				</tbody>
			</table>
			<div class=\"form-group\">" .
				($this->_allowed_to_access_link('Users', 'edit') ? "<a type=\"button\" href=\"" . Utilities::link_to("users/$user->id/edit") . "\" class=\"btn btn-primary\"><i class=\"fa fa-edit\">&nbsp;</i> " . _('Edit') . "</a>" : '') .
				"<a type=\"button\" href=\"" . Utilities::link_to('users') . "\" class=\"btn btn-default\"><i class=\"fa fa-step-backward\">&nbsp;</i> " . _('Back') . "</a>
			</div>";
	}

	function new($get, $post, $files) {
		$this->_form($get, $post, Utilities::link_to('users/create'));
	}

	function create($get, $post, $files) {
		$this->_validate($post, $files);
		$original_post = $post;
		if ($this->_error_messages) {
			$this->_form($get, $original_post, Utilities::link_to('users/create'));
			return;
		}
		$post['password'] = Utilities::encrypt_password('Sementara1');
		krsort($post['dob']);
		$post['dob'] = (new DateTime(implode('-', $post['dob'])))->format('Y-m-d');
		$period = [];
		$period['join'] = DateTime::createFromFormat('Ym', $post['join'])->format('Ym');
		$period['permanent'] = !empty($post['permanent']) ? DateTime::createFromFormat('Ym', $post['permanent'])->format('Ym') : null;
		$period['resign'] = !empty($post['resign']) ? DateTime::createFromFormat('Ym', $post['resign'])->format('Ym') : null;
		$id = parent::_db_insert('users', array_merge($post, $period));
		$this->_process_photo($files, str_repeat(0, 3 - strlen(id)) . $id);
		$this->_db->exec('REFRESH MATERIALIZED VIEW mv_users');
		$this->_alert = ['type' => 'success', 'message' => _('User created successfully')];
		Utilities::redirect_to("users/$id/edit");
	}

	function edit($get, $post, $files) {
		$user = $this->_prepare_data();
		foreach ($user as $k => $v) {
			if (isset($post[$k])) continue;
			if ($k == 'dob') {
				list($year, $month, $day) = explode('-', $v);
				$v = ['year' => $year, 'month' => $month, 'day' => $day];
			}
			$post[$k] = $v;
		}
		$this->_form($get, $post, Utilities::link_to("users/$user->id/update"));
	}

	function update($get, $post, $files) {
		$user = $this->_prepare_data();
		$this->_validate($post, $files);
		if ($this->_error_messages) {
			$this->_alert = ['type' => 'danger', 'message' => _('Record invalid')];
			foreach ($user as $k => $v) {
				!isset($post[$k]) && $post[$k] = $v;
			}
			$this->_form($get, $post, Utilities::link_to("users/$user->id/update"));
			return;
		}
		krsort($post['dob']);
		$post['dob'] = (new DateTime(implode('-', $post['dob'])))->format('Y-m-d');
		$period = [
			'join' => DateTime::createFromFormat('Ym', $post['join'])->format('Ym')
			, 'permanent' => $post['permanent'] ? DateTime::createFromFormat('Ym', $post['permanent'])->format('Ym') : null
			, 'resign' => $post['resign'] ? DateTime::createFromFormat('Ym', $post['resign'])->format('Ym') : null
		];
		parent::_db_update('users', array_merge($post, $period));
		$this->_process_photo($files, $user->id);
		$this->_db->exec('REFRESH MATERIALIZED VIEW mv_users');
		$this->_alert = ['type' => 'success', 'message' => _('User updated successfully')];
		Utilities::redirect_to("users/$user->id");
	}

	private function _form($get, $post, $action) {
		$id = str_repeat(0, 3 - strlen($this->_param['id'])) . $this->_param['id'];
		$this->_content .=
		'<h2 class="navbar-form navbar-left"><i class="fa fa-' . ($this->_param['id'] ? 'user' : 'user-plus') . '">&nbsp;</i> ' . _('User') . '</h2>
		<div class="clearfix"></div>' .
		$this->_get_form_notification() .
		'<form action="' . $action . '" method="POST" enctype="multipart/form-data" role="form">
			<input type="hidden" name="id" value="' . $this->_param['id'] . '">
			<div class="row form-inline">
				<div class="col-sm-2">&nbsp;</div>
				<div class="col-sm-2">
					<img src="/images/photos/' . (file_exists("images/photos/{$id}-sm.jpg") ? $id : 'anonymous') . '-sm.jpg">
				</div>
			</div>
			<div class="row form-inline">
				<div class="col-sm-2">
					<label for="name" class="control-label">* ' . _('Name') . '</label>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['first'] ? ' has-error error' : '') . '">
					<input id="first" name="first" type="text" value="' . $post['first'] . '" class="form-control" placeholder="' . _('First') . '">
					<span class="help-block' . ($this->_error_messages['first'] ? ' text-danger' : '') . '">' . _('First') . ' ' . $this->_error_messages['first'] . '</span>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['middle'] ? ' has-error error' : '') . '">
					<input id="middle" name="middle" type="text" value="' . $post['middle'] . '" class="form-control" placeholder="' . _('Middle') . '">
					<span class="help-block' . ($this->_error_messages['middle'] ? ' text-danger' : '') . '">' . _('Middle') . ' ' . $this->_error_messages['middle'] . '</span>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['last'] ? ' has-error error' : '') . '">
					<input id="last" name="last" type="text" value="' . $post['last'] . '" class="form-control" placeholder="' . _('Last') . '">
					<span class="help-block' . ($this->_error_messages['last'] ? ' text-danger' : '') . '">' . _('Last') . ' ' . $this->_error_messages['middle'] . '</span>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['alias'] ? ' has-error error' : '') . '">
					<input id="alias" name="alias" type="text" value="' . $post['alias'] . '" class="form-control" placeholder="' . _('Alias') . '">
					<span class="help-block' . ($this->_error_messages['alias'] ? ' text-danger' : '') . '">' . _('Alias') . ' ' . $this->_error_messages['alias'] . '</span>
				</div>
			</div>
			<div class="row form-inline">
				<div class="col-sm-2">
					<label for="birth" class="control-label">* ' . _('Place of Birth') . ' / ' . _('Date of Birth') . '</label>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['pob'] ? ' has-error error' : '') . '">
					<input id="pob" name="pob" type="text" value="' . $post['pob'] . '" class="form-control" placeholder="' . _('Place of Birth') . '">
					<span class="help-block' . ($this->_error_messages['pob'] ? ' text-danger' : '') . '">' . _('Place of Birth') . ' ' . $this->_error_messages['pob'] . '</span>
				</div>
				<div class="col-sm-6' . ($this->_error_messages['dob'] ? ' has-error error' : '') . '">
					<select class="form-control" id="dob_day" name="dob[day]">
						<option value="">&raquo;</option>';
					foreach (range(1, 31) as $i) {
						$d = $i < 10 ? '0' . $i : $i;
						$this->_content .= '<option value="' . $d . '"' . ($d == $post['dob']['day'] ? ' selected' : '') . '>' . $d . '</option>';
					}
					$this->_content .= '
					</select> - <select class="form-control" id="dob_month" name="dob[month]">
						<option value="">&raquo;</option>';
					foreach (['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'] as $k => $v) {
						$m = $k + 1;
						$m < 10 && $m = '0' . $m;
						$this->_content .= '<option value="' . $m . '"' . ($m == $post['dob']['month'] ? ' selected' : '') . '>' . $v . '</option>';
					}
					$this->_content .= '
					</select> - <select class="form-control" id="dob_year" name="dob[year]">
						<option value="">&raquo;</option>';
					foreach (range(1970, $this->_now->format('Y') - 10) as $i) {
						$this->_content .= '<option value="' . $i . '"' . ($i == $post['dob']['year'] ? ' selected' : '') . '>' . $i++ . '</option>';
					}
					$this->_content .= '
					</select>
					<span class="help-block' . ($this->_error_messages['dob'] ? ' text-danger' : '') . '">' . _('Date of Birth') . ' ' . $this->_error_messages['dob'] . '</span>
				</div>
			</div>
			<div class="row form-inline">
				<div class="col-sm-2">
					<label for="ktp_sim" class="control-label">* ' . _('KTP') . ' / ' . _('SIM') . ' / ' . _('NISN') . '</label>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['ktp_sim'] ? ' has-error error' : '') . '">
					<input id="ktp_sim" name="ktp_sim" type="text" value="' . $post['ktp_sim'] . '" class="form-control" placeholder="' . _('KTP') . ' / ' . _('SIM') . ' / ' . _('NISN') . '">
					<span class="help-block' . ($this->_error_messages['ktp_sim'] ? ' text-danger' : '') . '">' . $this->_error_messages['pob'] . '</span>
				</div>
			</div>
			<div class="row form-inline">
				<div class="col-sm-2">
					<label for="occupation" class="control-label">* ' . _('Occupation') . '</label>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['occupation'] ? ' has-error error' : '') . '">
					<input id="occupation" name="occupation" type="text" value="' . $post['occupation'] . '" class="form-control" placeholder="' . _('Occupation') . '">
					<span class="help-block' . ($this->_error_messages['occupation'] ? ' text-danger' : '') . '">' . $this->_error_messages['pob'] . '</span>
				</div>
			</div>
			<div class="row form-inline">
				<div class="col-sm-2">
					<label for="address" class="control-label">* ' . _('Address'). '</label>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['address'] ? ' has-error error' : '') . '">
					<input id="address" name="address" type="text" value="' . $post['address'] . '" class="form-control" placeholder="' . _('Address'). '">
					<span class="help-block' . ($this->_error_messages['address'] ? ' text-danger' : '') . '">' . _('Address') . ' ' . $this->_error_messages['address'] . '</span>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['city'] ? ' has-error error' : '') . '">
					<input id="city" name="city" type="text" value="' . $post['city'] . '" class="form-control" placeholder="' . _('City') . '">
					<span class="help-block' . ($this->_error_messages['city'] ? ' text-danger' : '') . '">' . _('City') . ' ' . $this->_error_messages['city'] . '</span>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['province'] ? ' has-error error' : '') . '">
					<input id="province" name="province" type="text" value="' . $post['province'] . '" class="form-control" placeholder="' . _('Province') . '">
					<span class="help-block' . ($this->_error_messages['province'] ? ' text-danger' : '') . '">' . _('Province') . ' ' . $this->_error_messages['province'] . '</span>
				</div>
			</div>
			<div class="row form-inline">
				<div class="col-sm-2">
					<label for="email" class="control-label">* ' . _('Email') . ' / ' . _('Mobile Phone') . ' / ' . _('Forbiscom ID') . '</label>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['email'] ? ' has-error error' : '') . '">
					<input id="email" name="email" type="text" value="' . $post['email'] . '" class="form-control" placeholder="' . _('Email') . '">
					<span class="help-block' . ($this->_error_messages['email'] ? ' text-danger' : '') . '">' . _('Email') . ' ' . $this->_error_messages['email'] . '</span>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['phone'] ? ' has-error error' : '') . '">
					<input id="phone" name="phone" type="text" value="' . $post['phone'] . '" class="form-control" placeholder="' . _('Mobile Phone') . '">
					<span class="help-block' . ($this->_error_messages['phone'] ? ' text-danger' : '') . '">' . _('Mobile Phone') . ' ' . $this->_error_messages['phone'] . '</span>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['forbiscom_id'] ? ' has-error error' : '') . '">
					<input id="forbiscom_id" name="forbiscom_id" type="text" value="' . $post['forbiscom_id'] . '" class="form-control" placeholder="' . _('Forbiscom User ID') . '">
					<span class="help-block' . ($this->_error_messages['forbiscom_id'] ? ' text-danger' : '') . '">' . _('Forbiscom User ID') . ' ' . $this->_error_messages['forbiscom_id'] . '</span>
				</div>
			</div>
			<div class="row form-inline">
				<div class="col-sm-2">
					<label for="photo" class="control-label">* ' . _('Photo') . '</label>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['photo'] ? ' has-error error' : '') . '">
					<input id="photo" name="photo" type="file">
					<span class="help-block' . ($this->_error_messages['photo'] ? ' text-danger' : '') . '">' . $this->_error_messages['photo'] . '</span>
				</div>
			</div>
			<div class="row form-inline">
				<div class="col-sm-2">
					<label for="role" class="control-label">* ' . _('Role') . '</label>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['role_id'] ? ' has-error error' : '') . '">';
				foreach ($this->_db->query("SELECT id, name FROM roles WHERE name <> 'Anonymous'") as $row) {
					$this->_content .= '<div class="radio"><label><input type="radio" name="role_id" value="' . $row['id'] . '"' . ($row['id'] == $post['role_id'] ? ' checked' : '') . '> ' . $row['name'] . '</label></div><br>';
				}
				$this->_content .=
					'<span class="help-block' . ($this->_error_messages['role_id'] ? ' text-danger' : '') . '">' . $this->_error_messages['role_id'] . '</span>
				</div>
			</div>
			<div class="row form-inline">
				<div class="col-sm-2">
					<label for="period" class="control-label">* ' . _('Join') . ' / ' . _('Permanent') . ' / ' . _('Resign') . '</label>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['join'] ? ' has-error error' : '') . '">
					<select id="join" name="join" class="form-control text-right">';
					$current_period = $this->_now->format('Ym');
					foreach ($this->_select_period_options as $k => $v) {
						if ($k > $current_period) {
							break;
						}
						$this->_content .= "<option value=\"$k\"" . ($k == $post['join'] ? ' selected' : '') . ">$v</option>";
					}
					$this->_content .= '
					</select>
					<span class="help-block' . ($this->_error_messages['join'] ? ' text-danger' : '') . '">' . _('Join') . ' ' . $this->_error_messages['join'] . '</span>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['permanent'] ? ' has-error error' : '') . '">
					<select id="permanent" name="permanent" class="form-control text-right">';

					foreach ($this->_select_period_options as $k => $v) {
						if ($k > $current_period) {
							break;
						}
						$this->_content .= "<option value=\"$k\"" . ($k == $post['permanent'] ? ' selected' : '') . ">$v</option>";
					}

					$this->_content .= '
					</select>
					<span class="help-block' . ($this->_error_messages['permanent'] ? ' text-danger' : '') . '">' . _('Permanent') . ' ' . $this->_error_messages['permanent'] . '</span>
				</div>
				<div class="col-sm-2' . ($this->_error_messages['resign'] ? ' has-error error' : '') . '">
					<select id="resign" name="resign" class="form-control text-right">';

					foreach ($this->_select_period_options as $k => $v) {
						if ($k > $current_period) {
							break;
						}
						$this->_content .= "<option value=\"$k\"" . ($k == $post['resign'] ? ' selected' : '') . ">$v</option>";
					}

					$this->_content .= '
					</select>
					<span class="help-block' . ($this->_error_messages['resign'] ? ' text-danger' : '') . '">' . _('Resign') . ' ' . $this->_error_messages['resign'] . '</span>
				</div>
			</div>
			<div class="form-group">
				<button type="submit" class="btn btn-primary"><i class="fa fa-save">&nbsp;</i> Simpan</button>
				<button type="reset" class="btn btn-danger"><i class="fa fa-undo">&nbsp;</i> Reset</button>
				<a type="button" href="' . Utilities::link_to('users') . '" class="btn btn-default"><i class="fa fa-step-backward">&nbsp;</i> ' . _('Back') . '</a>
			</div>
		</form>';
	}

	private function _validate($post, $files) {
		if (empty($post['first'])) {
			$this->_error_messages['first'] = _('is blank');
		} else if (!preg_match('/^[A-Za-z\.]+$/', $post['first'])) {
			$this->_error_messages['first'] = _('is invalid');
		}

		if (!empty($post['middle']) && !preg_match('/^[A-Za-z\. ]+$/', $post['middle'])) {
			$this->_error_messages['middle'] = _('is invalid');
		}

		if (!empty($post['last']) && !preg_match('/^[A-Za-z\. ]+$/', $post['last'])) {
			$this->_error_messages['last'] = _('is invalid');
		}

		if (empty($post['alias'])) {
			$this->_error_messages['alias'] = _('is blank');
		} else if (!preg_match('/^[A-Za-z ]+$/', $post['alias'])) {
			$this->_error_messages['alias'] = _('is invalid');
		}

		if (empty($post['pob'])) {
			$this->_error_messages['pob'] = _('is blank');
		} else if (!preg_match('/^[A-Za-z,\.\- ]+$/', $post['pob'])) {
			$this->_error_messages['pob'] = _('is invalid');
		}

		$dob_error_messages = [];
		foreach (['year', 'month', 'day'] as $k) {
			empty($post['dob'][$k]) && $dob_error_messages[] = "$k " . _('is blank');
		}
		if (empty($dob_error_messages)) {
			$date = new DateTime(join('-', $post['dob']));
			!$date && $dob_error_messages[] = _('is invalid');
		}
		$dob_error_messages && $this->_error_messages['dob'] = join(', ', $dob_error_messages);

		if (empty($post['ktp_sim'])) {
			$this->_error_messages['ktp_sim'] = _('is blank');
		} else if ($this->_db->query("SELECT COUNT(1) FROM mv_users WHERE resign IS NULL AND ktp_sim = '{$post['ktp_sim']}'" . ($this->_param['id'] ? " AND id <> {$this->_param['id']}" : ''))->fetchColumn()) {
			$this->_error_messages['ktp_sim'] = _('is taken');
		}

		if (empty($post['occupation'])) {
			$this->_error_messages['occupation'] = _('is blank');
		} else if (!preg_match('/^[A-Za-z ]+$/', $post['occupation'])) {
			$this->_error_messages['occupation'] = _('is invalid');
		}

		if (empty($post['address'])) {
			$this->_error_messages['address'] = _('is blank');
		} else if (!preg_match('/^[A-Za-z0-9,\.\-() ]+$/', $post['address'])) {
			$this->_error_messages['address'] = _('is invalid');
		}

		if (empty($post['city'])) {
			$this->_error_messages['city'] = _('is blank');
		} else if (!preg_match('/^[A-Za-z\. ]+$/', $post['city'])) {
			$this->_error_messages['city'] = _('is invalid');
		}

		if (empty($post['province'])) {
			$this->_error_messages['province'] = _('is blank');
		} else if (!preg_match('/^[A-Za-z ]+$/', $post['province'])) {
			$this->_error_messages['province'] = _('is invalid');
		}

		if (empty($post['email'])) {
			$this->_error_messages['email'] = _('is blank');
		} else if (!preg_match('/^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i', $post['email'])) {
			$this->_error_messages['email'] = _('is invalid');
		} else if ($this->_db->query("SELECT COUNT(1) FROM mv_users WHERE resign IS NULL AND email = '{$post['email']}'" . ($this->_param['id'] ? " AND id <> {$this->_param['id']}" : ''))->fetchColumn()) {
			$this->_error_messages['email'] = _('is taken');
		}

		if (empty($post['phone'])) {
			$this->_error_messages['phone'] = _('is blank');
		} else if (!ctype_digit($post['phone'])) {
			$this->_error_messages['phone'] = _('is invalid');
		} else if ($this->_db->query("SELECT COUNT(1) FROM mv_users WHERE resign IS NULL AND phone = '{$post['phone']}'" . ($this->_param['id'] ? " AND id <> {$this->_param['id']}" : ''))->fetchColumn()) {
			$this->_error_messages['phone'] = _('is taken');
		}

		if (empty($post['forbiscom_id'])) {
			$this->_error_messages['forbiscom_id'] = _('is blank');
		} else if (!preg_match('/^[A-Za-z0-9._\- ]+$/', $post['forbiscom_id'])) {
			$this->_error_messages['forbiscom_id'] = _('is invalid');
		} else if ($this->_db->query("SELECT COUNT(1) FROM mv_users WHERE resign IS NULL AND forbiscom_id = '{$post['forbiscom_id']}'" . ($this->_param['id'] ? " AND id <> {$this->_param['id']}" : ''))->fetchColumn()) {
			$this->_error_messages['forbiscom_id'] = _('is taken');
		}

		if (empty($post['join'])) {
			$this->_error_messages['join'] = _('is blank');
		}

		if ($this->_error_messages) {
			$this->_alert = ['type' => 'danger', 'message' => _('Record invalid')];
		}
	}

	private function _prepare_data() {
		$stmt = $this->_db->prepare('SELECT * FROM mv_users WHERE resign IS NULL AND id = ?');
		$stmt->execute([$this->_param['id']]);
		$user = $stmt->fetchObject();
		if (!$user) {
			$this->_alert = ['type' => 'danger', 'message' => sprintf(_('User with ID %s is not found'), $user->id)];
			Utilities::redirect_to('users');
		}
		return $user;
	}

	private function _resize_image($origin, $w, $h, $crop = FALSE) {
		list($width, $height) = getimagesize($origin);
		$r = $width / $height;
		if ($crop) {
			if ($width > $height) {
				$width = ceil($width - ($width * abs($r - $w / $h)));
			} else {
				$height = ceil($height - ($height * abs($r - $w / $h)));
			}
			$new_width = $w;
			$new_height = $h;
		} else {
			if ($w / $h > $r) {
				$new_width = $h * $r;
				$new_height = $h;
			} else {
				$new_height = $w / $r;
				$new_width = $w;
			}
		}
		$src = imagecreatefromjpeg($origin);
		$dst = imagecreatetruecolor($new_width, $new_height);
		imagecopyresampled($dst, $src, 0, 0, 0, 0, $new_width, $new_height, $width, $height);
		imageinterlace($src, 1);
		imagejpeg($dst, $origin, 100);
		foreach ([$src, $dst] as $k) { imagedestroy($k); }
	}

	private function _process_photo($files, $id) {
		$photo = &$files['photo'];
		if (empty($photo['tmp_name']) || !empty($photo['error']) || !in_array(exif_imagetype($photo['tmp_name']), [IMAGETYPE_JPEG, IMAGETYPE_PNG])) return;
		$filename = "images/photos/$id";
		move_uploaded_file($photo['tmp_name'], $filename . '.jpg');
		copy($filename . '.jpg', $filename . '-md.jpg');
		copy($filename . '.jpg', $filename . '-sm.jpg');
		$this->_resize_image($filename . '.jpg', 480, 480, true);
		$this->_resize_image($filename . '-md.jpg', 80, 80, true);
		$this->_resize_image($filename . '-sm.jpg', 50, 50, true);
	}
}