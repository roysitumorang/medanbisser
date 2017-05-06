<?php

class Monthly_Cashes extends Application {
	protected $_current_year;

	function __construct($db, $route) {
		parent::__construct($db, $route);
		!apcu_exists('monthly_cashes_order_fields') && apcu_add('monthly_cashes_order_fields', new ArrayObject(['Nama' => 'full_name', 'Nomor ID' => 'id']));
		$this->_order_fields = apcu_fetch('monthly_cashes_order_fields');
		$this->_current_year = $this->_now->format('Y');
	}

	function index($get, $post, $files) {
		parent::index($get, $post, $files);
		$params = [];
		if (!empty($get['q'])) {
			$q = '%' . strtolower($get['q']) . '%';
			$params = [$q, $q];
			$this->_query .= ' AND (u.id::text LIKE ? OR LOWER(u.full_name) LIKE ?)';
		}
		$this->_paginate($get, Utilities::link_to('monthly-cashes'), $params, 'u.id, u.full_name, u.paid, u.debt, u.months_of_debt, c.prev_01, c.prev_02, c.prev_03, c.prev_04, c.prev_05, c.prev_06, c.prev_07, c.prev_08, c.prev_09, c.prev_10, c.prev_11, c.prev_12, c.cur_01, c.cur_02, c.cur_03, c.cur_04, c.cur_05, c.cur_06, c.cur_07, c.cur_08, c.cur_09, c.cur_10, c.cur_11, c.cur_12');
		$last_year = $this->_current_year - 1;

		$this->_content .= '
			<h2 class="navbar-form navbar-left"><i class="fa fa-dollar">&nbsp;</i> ' . ngettext('Monthly Cash', 'Monthly Cashes', 2) . '</h2>
			<form method="GET" action="' . Utilities::link_to('monthly-cashes') . '" class="navbar-form navbar-right" role="search" onsubmit="(\'' . _('Search') . '\'==$(\'[name=q\').val())&amp;&amp;$(\'[name=q]\').val(\'\')">
				<input type="text" name="q" value="' . $get['q'] . '" class="form-control" placeholder="' . _('Search') . '">
				<button type="submit" class="btn btn-default"><i class="fa fa-search">&nbsp;</i> ' . _('Search') . '</button>';
		$this->_content .= $this->_allowed_to_access_link('Monthly_Cashes', 'create') ? '<a type="button" href="' . Utilities::link_to('monthly-cashes/new') . '" class="btn btn-default"><i class="fa fa-user-plus">&nbsp;</i> ' . _('New') . '</a>' : '';
		$colspan = count($this->_periods) - 12;
		$this->_content .= '
			</form>
			<div class="clearfix"></div>' .
			$this->_pagination .
			'<table class="table table-striped table-hover table-condensed">
				<thead>
					<tr>
						<th class="text-center" rowspan="2">' . _('ID') . '</th>
						<th class="text-center" rowspan="2">' . _('Name') . '</th>
						<th class="text-center" colspan="12">' . $last_year . '</th>
						<th class="text-center" colspan="' . $colspan . '">' . $this->_current_year . '</th>
						<th class="text-center" rowspan="2">' . _('Paid') . '</th>
						<th class="text-center" rowspan="2">' . _('Debt') . '</th>
					</tr>
					<tr>';

		foreach ($this->_periods as $k => $v) {
			$this->_content .= '<th class="text-center">' . $v . '</th>';
		}

		$this->_content .=<<<CONTENT
					</tr>
				</thead>
				<tbody>
CONTENT;

		while ($this->_rows->valid()) {
			$row = $this->_rows->current();
			$id = str_repeat('0', 3 - strlen($row->id)) . $row->id;
			$this->_content .= "
					<tr>
						<td class=\"text-center\">$id</td>
						<td class=\"text-nowrap\">$row->full_name</td>";
			foreach ($this->_periods as $k => $v) {
				$f = (substr($k, 0, 4) < $this->_current_year ? 'prev' : 'cur') .'_' . substr($k, 4, 2);
				$this->_content .= '<td class="text-center">' . $row->$f . '</td>';
			}
			$this->_content .= "
						<td class=\"text-right text-nowrap\">" . number_format($row->paid) . "</td>
						<td class=\"text-right text-nowrap\">" . ($row->months_of_debt ? sprintf(ngettext('%d Month', '%d Months', $row->months_of_debt), $row->months_of_debt) . ' / ' . number_format($row->debt) : '-') . "</td>
					</tr>";
			$this->_rows->next();
		}

		$this->_content .=<<<CONTENT
				</tbody>
			</table>
			$this->_pagination
CONTENT;
	}

	function create($get, $post, $files) {
		$months = new SplFixedArray(12);
		foreach (range(1, 12) as $i) {
			$months->offsetSet($i - 1, sprintf('%s%d', $i < 10 ? '0' : '', $i));
		}
		$stmt = $this->_db->prepare('WITH upsert AS (UPDATE mv_cashes SET "01" = :01, "02" = :02, "03" = :03, "04" = :04, "05" = :05, "06" = :06, "07" = :07, "08" = :08, "09" = :09, "10" = :10, "11" = :11, "12" = :12, modified_by = :by, modified_ip = :ip, modified_at = :at WHERE user_id = :user_id AND year_id = :year_id RETURNING 1) INSERT INTO mv_cashes (user_id, year_id, "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", created_by, created_ip, created_at) SELECT :user_id, :year_id, :01, :02, :03, :04, :05, :06, :07, :08, :09, :10, :11, :12, :by, :ip, :at WHERE NOT EXISTS(SELECT 1 FROM upsert)');
		$params = [[':by', $_SESSION['user_id']]
			, [':ip', Utilities::get_real_ip_address()]
			, [':at', $this->_now->format('Y-m-d H:i:s')]];
		foreach ($params as $param) {
			call_user_func_array([$stmt, 'bindValue'], $param);
		}
		foreach ($post['last_pay_period'] as $user_id => $last_pay_period) {
			if (!is_int($user_id) || !($user = $this->_db->query('SELECT last_pay_period, "join" FROM mv_users WHERE resign IS NULL AND id = ' . $user_id)->fetchObject())) continue;
			if (ctype_digit($last_pay_period) || strlen($last_pay_period) == 6) {
				$interval = new DateInterval('P1M');
				$start = new DateTime(($user->last_pay_period ?: $user->join) . '01');
				$user->last_pay_period && $start->add($interval);
				foreach (new DatePeriod($start, $interval, DateTime::createFromFormat('Ym', $last_pay_period)) as $date) {
					parent::_db_insert('cashes', [
						'user_id' => $user_id
						, 'period_id' => $date->format('Ym')
						, 'dop' => $this->_now->format('Y-m-d')
					]);
				}
			}
			$stmt->bindValue(':user_id', $user_id);
			foreach (range(substr($user->join, 0, 4), $this->_current_year) as $year) {
				$stmt->bindValue(':year_id', $year);
				$months->rewind();
				while ($months->valid()) {
					$period = $year . $months->current();
					$stmt->bindValue(
						':' . $months->current()
						, call_user_func_array(function($period, $user, $last_pay_period) {
							if ($period < $user->join) {
								return 'x';
							} else if ($period > $last_pay_period && $period > $this->_now->format('Ym')) {
								return '0';
							} else if ($period <= $last_pay_period) {
								return '10';
							}
							return '-10';
						}, [$period, $user, $last_pay_period])
					);
					$months->next();
				}
				$stmt->execute();
			}
		}
		$this->_db->exec('REFRESH MATERIALIZED VIEW mv_users;REFRESH MATERIALIZED VIEW mv_last_two_years_cashes');
		$this->_alert = ['type' => 'success', 'message' => _('Monthly cashes saved successfully')];
		$this->_form($get, $post, Utilities::link_to('monthly-cashes/create'));
	}

	function new($get, $post, $files) {
		$this->_form($get, $post, Utilities::link_to('monthly-cashes/create'));
	}

	private function _form($get, $post, $action) {
		$this->_content .=
		'<h2 class="navbar-form navbar-left"><i class="fa fa-dollar">&nbsp;</i> ' . ngettext('Monthly Cash', 'Monthly Cashes', 2) . '</h2>
		<div class="clearfix"></div>' .
		$this->_get_form_notification() .
		'<form action="' . $action . '" method="POST" role="form">
			<table class="table table-striped table-hover table-condensed">
				<thead>
					<tr>
						<th class="text-center" rowspan="2">' . _('ID') . '</th>
						<th class="text-center" rowspan="2">' . _('Name') . '</th>
						<th class="text-center" colspan="12">' . ($this->_current_year - 1) . '</th>
						<th class="text-center" colspan="' . (count($this->_periods) - 12) . '">' . $this->_current_year . '</th>
						<th class="text-center" rowspan="2">' . _('Paid') . '</th>
						<th class="text-center" rowspan="2">' . _('Debt') . '</th>
						<th class="text-center" rowspan="2">' . _('Paid') . ' ' . _('up to') . '</th>
					</tr>
					<tr>';

		foreach ($this->_periods as $k => $v) {
			$this->_content .= '<th class="text-center">' . $v . '</th>';
		}

		$this->_content .= '
					</tr>
				</thead>
				<tbody>';

		$result = $this->_db->query('SELECT u.id, u.full_name, u.last_pay_period, u.paid, u.months_of_debt, u.debt, m.prev_01, m.prev_02, m.prev_03, m.prev_04, m.prev_05, m.prev_06, m.prev_07, m.prev_08, m.prev_09, m.prev_10, m.prev_11, m.prev_12, m.cur_01, m.cur_02, m.cur_03, m.cur_04, m.cur_05, m.cur_06, m.cur_07, m.cur_08, m.cur_09, m.cur_10, m.cur_11, m.cur_12 FROM mv_users u LEFT JOIN mv_last_two_years_cashes m USING(id) WHERE u.resign IS NULL ORDER BY u.full_name');
		while ($row = $result->fetchObject()) {
			$id = str_repeat('0', 3 - strlen($row->id)) . $row->id;
			$this->_content .= "
					<tr>
						<td class=\"text-center\">$id</td>
						<td class=\"text-nowrap\">$row->full_name</td>";

			foreach ($this->_periods as $k => $v) {
				$f = (substr($k, 0, 4) < $this->_current_year ? 'prev' : 'cur') .'_' . substr($k, 4, 2);
				$this->_content .= '<td class="text-center">' . $row->$f . '</td>';
			}

			$this->_content .= "
						<td class=\"text-right text-nowrap\">" . number_format($row->paid) . "</td>
						<td class=\"text-right text-nowrap\">" . ($row->months_of_debt ? sprintf(ngettext('%d Month', '%d Months', $row->months_of_debt), $row->months_of_debt) . ' / ' . number_format($row->debt) : '-') . "</td>
						<td>
							<select name=\"last_pay_period[$row->id]\" class=\"text-right\">";

			foreach ($this->_select_period_options as $k => $v) {
				if ((!$k && $row->last_pay_period) || ($k && ($k < $row->join || $k < $row->last_pay_period))) continue;
				$this->_content .= "<option value=\"$k\"" . ($k == $post['last_pay_period'][$row->id] || $k == $row->last_pay_period ? ' selected' : '') . ">$v</option>";
			}

			$this->_content .=
							"</select>
						</td>
					</tr>";
		}

		$this->_content .= '
					</tbody>
				</table>
				<div class="form-group">
					<button type="submit" class="btn btn-primary"><i class="fa fa-save">&nbsp;</i> ' . _('Save') . '</button>
					<button type="reset" class="btn btn-danger"><i class="fa fa-undo">&nbsp;</i> ' . _('Reset') . '</button>
					<a type="button" href="' . Utilities::link_to('monthly-cashes') . '" class="btn btn-default"><i class="fa fa-step-backward">&nbsp;</i> ' . _('Back') . '</a>
				</div>
			</form>';

		$this->_javascript .= '$("[name*=last_pay_period]").datepicker({changeMonth:!0,changeYear:!0,dateFormat:"MM yy"})';
	}
}