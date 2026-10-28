<?php

class Meetups extends Application {
	protected $_current_year, $_current_period;

	function __construct($db, $route) {
		parent::__construct($db, $route);
		$this->_order_fields = $this->_cached('meetups_order_fields', fn() => ['Nama' => 'full_name', 'Nomor ID' => 'id']);
		$this->_current_year = $this->_now->format('Y');
		$this->_current_period = $this->_now->format('Ym');
	}

	function index($get, $post, $files) {
		parent::index($get, $post, $files);
		$params = [];
		if (!empty($get['q'])) {
			$q = sprintf('%%%s%%', $get['q']);
			$params = [$q, $q];
			$this->_query .= ' WHERE u.id::text LIKE ? OR u.full_name LIKE ?';
		}
		$this->_paginate($get, Utilities::link_to('meetups'), $params, 'u.id, u.full_name, m.prev_01, m.prev_02, m.prev_03, m.prev_04, m.prev_05, m.prev_06, m.prev_07, m.prev_08, m.prev_09, m.prev_10, m.prev_11, m.prev_12, m.cur_01, m.cur_02, m.cur_03, m.cur_04, m.cur_05, m.cur_06, m.cur_07, m.cur_08, m.cur_09, m.cur_10, m.cur_11, m.cur_12');
		$this->_content .= '
			<h2 class="navbar-form navbar-left"><i class="fa fa-calendar">&nbsp;</i> ' . ngettext('Meetup', 'Meetups', 2) . '</h2>
			<form method="GET" action="' . Utilities::link_to('meetups') . '" class="navbar-form navbar-right" role="' . _('Search') . '" onsubmit="(\'' . _('Search') . '\'==$(\'[name=q]\').val())&amp;&amp;$(\'[name=q]\').val(\'\')">
				<input type="text" name="q" value="' . htmlspecialchars($get['q'] ?? '') . '" class="form-control" placeholder="' . _('Search') . '">
				<button type="submit" class="btn btn-default"><i class="fa fa-search">&nbsp;</i> ' . _('Search') . '</button>';

		$this->_content .= $this->_allowed_to_access_link('Meetups', 'edit') ? '<a type="button" href="/meetups/edit" class="btn btn-default"><i class="fa fa-edit">&nbsp;</i> ' . _('Edit') . '</a>' : '';

		$this->_content .= '
			</form>
			<div class="clearfix"></div>' .
			$this->_pagination .
			'<table class="table table-striped table-hover table-condensed">
				<thead>
					<tr>
						<th class="text-center" rowspan="2">' . _('ID') . '</th>
						<th class="text-center" rowspan="2">' . _('Name') . '</th>
						<th class="text-center" colspan="12">';

		$this->_content .= ($this->_current_year - 1) .
						'</th>
						<th class="text-center" colspan="' . (count($this->_periods) - 12) . '">' . $this->_current_year . '</th>
					</tr>
					<tr>';

		foreach ($this->_periods as $k => $v) {
			$this->_content .= '<th class="text-center">' . $v . '</th>';
		}

		$this->_content .= '
					</tr>
				</thead>
				<tbody>';

		foreach ($this->_rows as $row) {
			$id = Utilities::pad_id($row->id);
			$this->_content .=
					"<tr>
						<td class=\"text-center\">$id</td>
						<td class=\"text-nowrap\">$row->full_name</td>";

			foreach ($this->_periods as $k => $v) {
				$f = (substr($k, 0, 4) < $this->_current_year ? 'prev' : 'cur') .'_' . substr($k, 4, 2);
				$this->_content .= '<td class="text-center">' . $row->$f . '</td>';
			}

			$this->_content .= '</tr>';
		}

		$this->_content .=<<<CONTENT
				</tbody>
			</table>
			$this->_pagination
CONTENT;
	}

	function save($get, $post, $files) {
		//$this->_validate($post, $files);
		$users = SplFixedArray::fromArray($post['user_id'] ?? []);
		$months = new SplFixedArray(12);
		foreach (range(1, 12) as $i) {
			$months->offsetSet($i - 1, $i < 10 ? "0{$i}" : "$i");
		}
		$stmt = $this->_db->prepare('WITH upsert AS (UPDATE mv_meetups SET "01" = :01, "02" = :02, "03" = :03, "04" = :04, "05" = :05, "06" = :06, "07" = :07, "08" = :08, "09" = :09, "10" = :10, "11" = :11, "12" = :12, modified_by = :by, modified_ip = :ip, modified_at = :at WHERE user_id = :user_id AND year_id = :year_id RETURNING 1) INSERT INTO mv_meetups (user_id, year_id, "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", created_by, created_ip, created_at) SELECT :user_id, :year_id, :01, :02, :03, :04, :05, :06, :07, :08, :09, :10, :11, :12, :by, :ip, :at WHERE NOT EXISTS(SELECT 1 FROM upsert)');
		$params = [[':by', $_SESSION['user_id'] ?? null]
			, [':ip', Utilities::get_real_ip_address()]
			, [':at', $this->_now->format('Y-m-d H:i:s')]];
		foreach ($params as $param) {
			call_user_func_array([$stmt, 'bindValue'], $param);
		}
		foreach ($this->_db->query('SELECT u.id, u.full_name, u.join, m.prev_01, m.prev_02, m.prev_03, m.prev_04, m.prev_05, m.prev_06, m.prev_07, m.prev_08, m.prev_09, m.prev_10, m.prev_11, m.prev_12, m.cur_01, m.cur_02, m.cur_03, m.cur_04, m.cur_05, m.cur_06, m.cur_07, m.cur_08, m.cur_09, m.cur_10, m.cur_11, m.cur_12 FROM mv_users u LEFT JOIN mv_last_two_years_meetups m USING(id) WHERE u.resign IS NULL ORDER BY u.full_name') as $row) {
			$users->offsetExists($row['id'])
			&& !$this->_scalar('SELECT COUNT(*) FROM meetups WHERE user_id = ? AND period_id = ?', [$row['id'], $this->_current_period])
			&& parent::_db_insert('meetups', ['user_id' => $row['id'], 'period_id' => $this->_current_period]);
			$stmt->bindValue(':user_id', $row['id']);
			foreach (range((int) substr((string) $row['join'], 0, 4), (int) $this->_current_year) as $year) {
				$stmt->bindValue(':year_id', $year);
				$months->rewind();
				while ($months->valid()) {
					$period = $year . $months->current();
					$stmt->bindValue(
						':' . $months->current()
						, $users->offsetExists($row['id']) || $this->_scalar('SELECT COUNT(*) FROM meetups WHERE user_id = ? AND period_id = ?', [$row['id'], $period])
						? '&#x2713;'
						: 'x'
					);
					$months->next();
				}
				$stmt->execute();
			}
		}
		$this->_db->exec('REFRESH MATERIALIZED VIEW mv_last_two_years_meetups');
		$this->_alert = ['type' => 'success', 'message' => 'Berhasil menyimpan data'];
		$this->_form($get, $post, '/meetups/save');
	}

	function edit($get, $post, $files) {
		$this->_form($get, $post, '/meetups/save');
	}

	private function _form($get, $post, $action) {
		$this->_content .=
		'<h2 class="navbar-form navbar-left"><i class="fa fa-calendar">&nbsp;</i> ' . ngettext('Meetup', 'Meetups', 1) . '</h2>
		<div class="clearfix"></div>' .
		$this->_get_form_notification() .
		'<form action="' . $action . '" method="POST" role="form">
			<table class="table table-striped table-hover table-condensed">
				<thead>
					<tr>
						<th class="text-center" rowspan="2">' . _('ID') . '</th>
						<th class="text-center" rowspan="2">' . _('Name') . '</th>
						<th class="text-center" colspan="12">' . ($this->_current_year - 1) . '</th>
						<th class="text-center" colspan="12">' . $this->_current_year . '</th>
					</tr>
					<tr>';

		foreach ($this->_periods as $k => $v) {
			$this->_content .= '<th class="text-center">' . $v . '</th>';
		}

		$this->_content .= '
					</tr>
				</thead>
				<tbody>';

		foreach ($this->_db->query('SELECT u.id, u.full_name, m.prev_01, m.prev_02, m.prev_03, m.prev_04, m.prev_05, m.prev_06, m.prev_07, m.prev_08, m.prev_09, m.prev_10, m.prev_11, m.prev_12, m.cur_01, m.cur_02, m.cur_03, m.cur_04, m.cur_05, m.cur_06, m.cur_07, m.cur_08, m.cur_09, m.cur_10, m.cur_11, m.cur_12 FROM mv_users u LEFT JOIN mv_last_two_years_meetups m USING(id) WHERE u.resign IS NULL ORDER BY u.full_name') as $row) {
			$id = Utilities::pad_id($row['id']);
			$this->_content .= "
					<tr>
						<td class=\"text-center\">$id</td>
						<td class=\"text-nowrap\">{$row['full_name']}</td>";

			foreach ($this->_periods as $k => $v) {
				$f = (substr($k, 0, 4) < $this->_current_year ? 'prev' : 'cur') .'_' . substr($k, 4, 2);
				$this->_content .= '<td class="text-center">'
				. ($k == $this->_current_period && $row[$f] <> '&#x2713;'
				? "<input type=\"checkbox\" name=\"user_id[{$row['id']}]\" value=\"1\">"
				: $row[$f])
				. '</td>';
			}

			$this->_content .= "</tr>";
		}

		$this->_content .= '
					</tbody>
				</table>
				<div class="form-group">
					<button type="submit" class="btn btn-primary"><i class="fa fa-save">&nbsp;</i> ' . _('Save') . '</button>
					<button type="reset" class="btn btn-danger"><i class="fa fa-undo">&nbsp;</i> ' . _('Reset') . '</button>
					<a type="button" href="/meetups" class="btn btn-default"><i class="fa fa-step-backward">&nbsp;</i> ' . _('Back') . '</a>
				</div>
			</form>';

		$this->_javascript .= '$("[name*=last_pay_period]").datepicker({changeMonth:!0,changeYear:!0,dateFormat:"MM yy"})';
	}

	private function _validate($post, $files) {
	}
}