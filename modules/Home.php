<?php

class Home extends Application {
	function index($get, $post, $files) {
		if (!$_SESSION['user_id']) {
			return $this->_form($get, $post, $files);
		}
		$user = $this->_db->query("SELECT * FROM mv_users WHERE id = {$_SESSION['user_id']}")->fetchObject();
		$missing_datas = [];
		empty($user->alias) && $missing_datas[] = _('Alias');
		empty($user->pob) && $missing_datas[] = _('Place of Birth');
		empty($user->dob) && $missing_datas[] = _('Date of Birth');
		empty($user->ktp_sim) && $missing_datas[] = _('KTP') . ' / ' . _('SIM') . ' / ' . _('NISN');
		empty($user->occupation) && $missing_datas[] = _('Occupation');
		empty($user->address) && $missing_datas[] = _('Address');
		empty($user->city) && $missing_datas[] = _('City');
		empty($user->province) && $missing_datas[] = _('Province');
		empty($user->email) && $missing_datas[] = _('Email');
		empty($user->phone) && $missing_datas[] = _('Mobile Phone');
		empty($user->forbiscom_id) && $missing_datas[] = _('Forbiscom User ID');
		!file_exists("images/photos/{$user->id}.jpg") && $missing_datas[] = _('Photo');
		$cash = $this->_db->query("SELECT (SELECT SUM(10000 + CASE WHEN dop >= '2014-05-01' AND DATE_FORMAT(dop, '%Y%m')::bigint > period_id THEN 2500 ELSE 0 END) FROM cashes) AS gross_amount, (SELECT COALESCE(SUM(amount), 0) AS amount FROM expenses) AS expense")->fetchObject();
		$period = $this->_period_formatter->format($this->_now);

		$this->_content .= '
				<h2 class="navbar-form navbar-left"><i class="fa fa-home">&nbsp;</i>&nbsp;' . sprintf(_('Welcome %s'), '<a href="' . Utilities::link_to('sessions/mine') . '">&nbsp;' . $user->full_name . '</a>') . '</h2>
				<table class="table table-striped">
					<tr>
						<td colspan="3"><h4>' . sprintf(_('Cash of %s'), $period) . '</h4></td>
					</tr>
					<tr>
						<td>' . ($this->_allowed_to_access_link('Monthly_Cashes') ? '<a href="' . Utilities::link_to('monthly-cashes') . '">' . _('Total Income') . '</a>' : _('Total Income')) . '</td>
						<td>:</td>
						<td>Rp. ' . number_format($cash->gross_amount) . '</td>
					</tr>
					<tr>
						<td>' . ($this->_allowed_to_access_link('Expenses') ? '<a href="' . Utilities::link_to('expenses') . '">' . _('Total Expense') . '</a>' : _('Total Expense')) . '</td>
						<td>:</td>
						<td>Rp. ' . number_format($cash->expense) . '</td>
					</tr>
					<tr>
						<td>' . _('Total Income minus Total Expense') . '</td>
						<td>:</td>
						<td>Rp. ' . number_format($cash->gross_amount - $cash->expense) . '</td>
					</tr>';

		if (password_verify('Sementara1', $user->password)) {
			$this->_content .= '
					<tr>
						<td colspan="3" class="blink">' . sprintf(_('Currently you still use standard password. For security purpose, please click %shere%s to change it'), '&nbsp;<a href="' . Utilities::link_to('sessions/mine/edit') . '">', '</a>&nbsp;') . '.</td>
					</tr>';
		}

		$this->_content .=
					'<tr>
						<td>' . sprintf(_('Your cash of %s status'), $period) . '</td>
						<td>:</td>
						<td>
							<p>' . _('Paid') . ($user->last_pay_period ? ' ' . _('up to') . ' ' . $this->_period_formatter->format(new DateTime($user->last_pay_period . '01')) . ' /' : '') . ' Rp. ' . number_format($user->paid) . '</p>
							<p' . ($user->months_of_debt ? ' class="blink"' : '') . '>' . sprintf(_('Debt %d Months'), $user->months_of_debt) . ' / Rp. ' . number_format($user->debt) . '</p>' .
							($user->months_of_debt > 3 ? '<p class="blink">' . sprintf(_("You are getting a warning letter due to %d months late payment"), $user->months_of_debt) . '.<p>' : '') .
						'</td>
					</tr>';

		if ($missing_datas) {
			$this->_content .= '
					<tr>
						<td>Biodata</td>
						<td>:</td>
						<td class="blink">
							' . _('The following fields are still missing, please submit the datas to The Administrators to get the ID card') . '.
							<ul>';

			foreach ($missing_datas as $m) { $this->_content .= "<li>$m</li>"; }

			$this->_content .=
							'</ul>
						</td>
					</tr>';
		}

		$this->_content .= '</table>';
		$this->_javascript .= '!function blink(selector){$(selector).fadeOut("slow",function(){$(this).fadeIn("slow",blink(this))})}(".blink")';
	}

	function search($get, $post, $files) {
		$this->_form($get, $post, $files);
		if (!preg_match('/^\d{3}$/', $get['id'])) {
			$this->_content .= '<div class="alert alert-warning">' . _('Please fill the search form above with 3 digits of ID number printed on ID card') . '.</div>';
			return;
		}
		$result = $this->_db->query("SELECT id, full_name, resign FROM mv_users WHERE id = {$get['id']}");
		if (!$result->rowCount()) {
			$this->_content .= '<div class="alert alert-danger">' . sprintf(_('Medan Bisser member with ID %s is not found'), $get['id']) . '.</div>';
			return;
		}
		$user = $result->fetchObject();
		$resign = $user->resign ? $this->_period_formatter->format(new DateTime($user->resign . '01')) : null;
		$this->_content .= '<div class="alert alert-success">' . sprintf(_('Medan Bisser member with ID %s is found, the detail is as follow'), $get['id']) . ' :</div>
		<table class="table">
			<tr>
				<td rowspan="2"><img src="/images/photos/' . (file_exists("images/photos/{$get['id']}-md.jpg") ? $get['id'] : 'anonymous') . '-md.jpg"></td>
				<td>' . _('Name') . '</td>
				<td>:</td>
				<td>' . $user->full_name . '</td>
			</tr>
			<tr>
				<td>' . _('Membership Status') . '</td>
				<td>:</td>
				<td>' . ($resign ? '<i class="fa fa-close">&nbsp;</i> ' . sprintf(_("Resign as of %s. All of his activities are completely out of Medan Bisser's responsibility"), (new DateTime($resign))->format('F Y')) : '<i class="fa fa-check-circle">&nbsp;</i> ' . _('is active')) . '.</td>
			</tr>
		</table>';
		!$resign && $this->_content .= '<p>' . _("If you have complaint regarding our activities, please don't hesitate to let us know by sending email to info@medanbisser.com, thank you") . '</p>';
	}

	private function _form($get, $post, $files) {
		$this->_content .= '
		<h2>' . _('Welcome to') . '&nbsp;<strong>www.medanbisser.com</strong></h2>
		<p>
			' . _("For your information, official member of Medan Bisser has an ID card and should show it before doing activities") . '.<br>
			' . _('The ID card shows the following information') . ' :
			<ol>
				<li>' . _('Photo') . '</li>
				<li>' . _('Name') . '</li>
				<li>' . _('ID which consists of 3 digits in red colour') . '</li>
			</ol>
			' . _('To verify the ID card, please fill the search form below with the ID number printed on the ID card then click Search button') . '.<br>
			' . _('The valid ID card conforms all of the following conditions') . ' :
			<ol>
				<li>' . _('Photo printed on the ID card and the one displayed on the search result are identical') . '</li>
				<li>' . sprintf(_('Membership status displayed on the search result %sis active%s'), '&nbsp;<strong>', '</strong>') . '</li>
			</ol>
		</p>
		<form action="' . Utilities::link_to('search') . '" method="GET" role="form" class="form-inline">
			<div class="form-group">
				<label class="sr-only" for="id">' . _('ID number') . '</label>
				<input type="text" class="form-control" name="id" id="id" value="' . $get['id'] . '" placeholder="' . _('ID Number') . '">
			</div>
			<button type="submit" class="btn btn-default"><i class="fa fa-search">&nbsp;</i> ' . _('Search') . '</button>
		</form>';
	}
}