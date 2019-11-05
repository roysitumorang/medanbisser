<?php

abstract class Application {
	protected $_db, $_controller, $_method, $_param, $_content = '', $_pagination = '', $_query, $_module, $_error_messages = [], $_alert = [], $_limits, $_limit, $_page, $_offset, $_order_fields, $_order_by = '', $_rows, $_javascript = '', $_select_period_options, $_now, $_date_formatter, $_datetime_formatter, $_period_formatter, $_periods, $_locale;

	function __construct(PDO $db, $route = []) {
		$this->_db         = $db;
		$this->_controller = $route['controller'];
		$this->_method     = $route['method'] ?: 'index';
		$this->_param      = $route['param'];
		if (!apcu_exists('limits')) {
			$this->_limits = [10, 25, 50, 100];
			apcu_add('limits', $this->_limits);
		}
		$this->_limits         = apcu_fetch('limits');
		$this->_now            = new DateTime;
		$this->_error_messages = &$_SESSION['error_messages'];
		$this->_alert          = &$_SESSION['alert'];
		foreach (['date_formatter' => 'd MMM yyyy', 'datetime_formatter' => 'd MMM yyyy HH.mm', 'period_formatter' => 'MMM yyyy', 'month_formatter' => 'MMM'] as $k => $v) {
			$this->{"_$k"} = new IntlDateFormatter('id_ID', IntlDateFormatter::LONG, IntlDateFormatter::NONE, 'UTC', IntlDateFormatter::GREGORIAN, $v);
		}
		if (!apcu_exists('select_period_options')) {
			$this->_select_period_options = ['' => '&raquo;'];
			foreach (new DatePeriod(new DateTime('2013-01-01'), new DateInterval('P1M'), $this->_now) as $date) {
				$this->_select_period_options[$date->format('Ym')] = $this->_period_formatter->format($date);
			}
			apcu_add('select_period_options', $this->_select_period_options);
		}
		$this->_select_period_options = apcu_fetch('select_period_options');
		if (!apcu_exists('periods')) {
			$this->_periods = [];
			$now            = clone $this->_now;
			$now->setDate($now->format('Y') - 1, 1, 1);
			foreach (new DatePeriod($now, new DateInterval('P1M'), $this->_now) as $date) {
				$this->_periods[$date->format('Ym')] = $this->_month_formatter->format($date);
			}
			apcu_add('periods', $this->_periods);
		}
		$this->_periods = apcu_fetch('periods');
	}

	function __destruct() { }

	function index($get, $post, $files) {
		$stmt = $this->_db->prepare("SELECT r.query FROM modules m JOIN routes r ON m.id = r.module_id WHERE m.name = ? AND r.module_method = 'index'");
		$stmt->execute([get_class($this)]);
		$this->_query = $stmt->fetchColumn();
		if (isset($get['order_by']) && in_array($get['order_by'], $this->_order_fields)) {
			$this->_order_by = $this->_order_fields[$get['order_by']];
			return;
		}
		$this->_order_by = $this->_order_fields[array_key_first($this->_order_fields)];
	}

	protected function _paginate($get, $form_action, $params = [], $fields = '') {
		$this->_limit  = $this->_limits[$get['limit'] ?: 0];
		$this->_page   = $get['page'] && $get['page'] > 0 ? $get['page'] : 1;
		$this->_offset = ($this->_page - 1) * $this->_limit;
		$stmt          = $this->_db->prepare(strtr($this->_query, ['*' => 'COUNT(1)']));
		$stmt->execute($params);
		$total_rows_in_db = $stmt->fetchColumn();

		$fields && $this->_query = strtr($this->_query, ['*' => $fields]);
		$stmt = $this->_db->prepare($this->_query . " ORDER BY $this->_order_by LIMIT $this->_limit OFFSET $this->_offset");
		$stmt->execute($params);
		$total_rows_limited = $stmt->rowCount();
		$this->_rows        = [];
		while ($row = $stmt->fetchObject()) {
			$this->_rows[] = $row;
		}

		$this->_pagination .= '<form method="GET" action="' . $form_action . '" class="navbar-form navbar-right">';
		$get['q'] && $this->_pagination .= '<input type="hidden" name="q" value="' . $get['q'] . '">';
		$this->_pagination .= "<i class=\"fa fa-sort-alpha-asc\">&nbsp;</i>&nbsp;<strong>" . _('Sort by') . "&nbsp;:&nbsp;</strong>&nbsp;<select class=\"form-control\" name=\"order_by\" onchange=\"this.closest('form').submit()\">";
		foreach ($this->_order_fields as $key => $value) {
			$this->_pagination .= '<option value="' . $key . '"' . ($value == $this->_order_by ? ' selected' : '') . '>' . $key . '</option>';
		}
		$this->_pagination .= "</select><strong>&nbsp;,&nbsp;<i class=\"fa fa-sort-amount-asc\">&nbsp;</i>&nbsp;" . _('Size per page') . "&nbsp;:&nbsp;</strong>&nbsp;<select class=\"form-control\" name=\"limit\" onchange=\"$(this).closest('form').submit()\">";
		foreach ($this->_limits as $k => $v) {
			$this->_pagination .= "<option value=\"$k\"" . ($v == $this->_limit ? ' selected' : '') . ">$v</option>";
		}
		$this->_pagination .= '</select>';
		if ($total_rows_in_db > $this->_limit) {
			$total_pages        = ceil($total_rows_in_db / $this->_limit);
			$this->_pagination .= "<strong>&nbsp;,&nbsp;<i class=\"fa fa-sort-numeric-asc\">&nbsp;</i>&nbsp;" . sprintf(_('Total %d of %d items , Page'), $total_rows_limited, $total_rows_in_db) . "&nbsp;:&nbsp;</strong>&nbsp;";
			foreach (range(1, $total_pages) as $i) {
				$this->_pagination .= ($i > 1 ? ',' : '') . '&nbsp;' . ($i == $this->_page ? "<strong>$i</strong>" : "<a href=\"#\" data-page=\"$i\">$i</a>") . '&nbsp;';
			}
			$this->_pagination .= '<strong>&nbsp;' . sprintf(_('of %d pages'), $total_pages) . '</strong>';
		}
		$this->_pagination .= "</form>";
		$this->_javascript  = <<<CONTENT
			document.querySelectorAll("a[data-page]").forEach(element => {
				element.onclick = event => {
					let parent = event.target.parentNode, input = document.createElement('input');
					event.preventDefault(),
					input.type = 'hidden',
					input.name = 'page',
					input.value = event.target.dataset.page,
					parent.append(input),
					parent.submit()
				}
			})
CONTENT;
	}

	function get_content() { return $this->_content; }

	function get_javascript() { return $this->_javascript; }

	function get_right_menu() {
		$menu = '<li' . ($_SERVER['REQUEST_URI'] == Utilities::link_to('about-us') ? ' class="active"' : '') . '><a href="' . Utilities::link_to('about-us') . '"><i class="fa fa-info-circle">&nbsp;</i>&nbsp;' . _('About Us') . '</a></li><li';
		if ($_SESSION['user_id']) {
			$menu .= ' class="dropdown' . ($this->_controller == 'Sessions' ? ' active' : '') . '"><a class="dropdown-toggle" data-toggle="dropdown" href="#"><i class="fa fa-user">&nbsp;</i>&nbsp;' . _('Welcome') . ' ' . $this->_db->query("SELECT alias FROM users WHERE id = {$_SESSION['user_id']}")->fetchColumn() . '&nbsp;<b class="caret">&nbsp;</b></a><ul class="dropdown-menu"><li><a href="' . Utilities::link_to('sessions/mine') . '"><i class="fa fa-info">&nbsp;</i>&nbsp;' . _('About Me') . '</a></li><li><a href="' . Utilities::link_to('sessions/destroy') . '"><i class="fa fa-sign-out">&nbsp;</i>&nbsp;' . _('Logout') . '</a></li></ul>';
		} else {
			$menu .= ($this->_controller == 'Sessions' ? ' class="active"' : '') . '><a href="' . Utilities::link_to('sessions/new') . '"><i class="fa fa-sign-in">&nbsp;</i>&nbsp;' . _('Login') . '</a>';
		}
		$menu .= '</li><li class="dropdown">';
		$locales = $_SESSION['locale'] == array_keys(LOCALES)[0] ? LOCALES : array_reverse(LOCALES);
		foreach ($locales as $k => $v) {
			if ($k == $_SESSION['locale']) {
				$menu .= '<a class="dropdown-toggle" data-toggle="dropdown" href="#"><img alt="' . $k . '" src="/images/' . $k . '.png"><b class="caret">&nbsp;</b></a>';
				continue;
			}
			$menu .= '<ul class="dropdown-menu"><li><a href="/' . ($_SERVER['REQUEST_METHOD'] == 'GET' ? preg_replace("/^\/{$_SESSION['locale']}/", $k, $_SERVER['REQUEST_URI']) : "$k/home") . '" src="/images/' . $k . '.png"> ' . $v . '</a></li></ul>';
		}
		$menu .= '</li>';
		return $menu;
	}

	protected function _db_insert($table, $data = []) {
		foreach (['created_by', 'last_modified_by'] as $k) {
			$data[$k] = $_SESSION['user_id'];
		}
		foreach (['created_ip', 'last_modified_ip'] as $k) {
			$data[$k] = Utilities::get_real_ip_address();
		}
		foreach (['created_at', 'last_modified_at'] as $k) {
			$data[$k] = $this->_now->format('Y-m-d H:i:s');
		}
		$fields = [];
		$params = [];
		$result = $this->_db->query("SELECT * FROM $table LIMIT 0 OFFSET 1");
		$k = 0;
		foreach (range(0, $result->columnCount() - 1) as $i) {
			$field = $result->getColumnMeta($i);
			if ($field['name'] == 'id' || !isset($data[$field['name']])) continue;
			$fields[] = sprintf('"%s"', $field['name']);
			$params[] = $data[$field['name']] ?: null;
		}
		$stmt = $this->_db->prepare(sprintf('INSERT INTO %s (%s) VALUES (%s) RETURNING "id"', $table, implode(', ', $fields), implode(', ', array_fill(0, count($fields), '?'))));
		$stmt->execute($params);
		return $stmt->fetchColumn();
	}

	protected function _db_update($table, $data = []) {
		$skipped_fields = ['id', 'created_by', 'created_ip', 'created_at'];
		$data['modified_by'] = $_SESSION['user_id'];
		$data['modified_ip'] = Utilities::get_real_ip_address();
		$data['modified_at'] = $this->_now->format('Y-m-d H:i:s');
		$query = "UPDATE $table SET";
		$result = $this->_db->query("SELECT * FROM $table LIMIT 0 OFFSET 1");
		$params = [];
		$k = 0;
		foreach (range(0, $result->columnCount() - 1) as $i) {
			$field = $result->getColumnMeta($i);
			if (in_array($field['name'], $skipped_fields) || !isset($data[$field['name']])) continue;
			$query .= ($k++ ? ',' : '') . sprintf(' "%s" = ?', $field['name']);
			$params[] = $data[$field['name']] ?: null;
		}
		$query .= ' WHERE id = ?';
		$params[] = $data['id'];
		$stmt = $this->_db->prepare($query);
		$stmt->execute($params);
		return $stmt->rowCount();
	}

	protected function _db_delete($table, $id) {
		$stmt = $this->_db->prepare("DELETE FROM $table WHERE id = ?");
		$stmt->execute([$id]);
		return $stmt->rowCount();
	}

	protected function _get_form_notification() {
		return $this->_alert ? '<div class="alert alert-' . $this->_alert['type'] . '"><a class="close" href="#" data-dismiss="alert">x</a>' . $this->_alert['message'] . '</div>' : '';
	}

	protected function _allowed_to_access_link($controller, $method = 'index') {
		return in_array($method, $_SESSION['role_permissions'][$controller]);
	}
}