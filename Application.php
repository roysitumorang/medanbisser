<?php

abstract class Application {
	protected PDO $_db;
	protected string $_controller;
	protected string $_method;
	protected array $_param;
	protected string $_content    = '';
	protected string $_pagination = '';
	protected string $_javascript = '';
	protected string $_query      = '';
	protected string $_order_by   = '';
	protected array $_order_fields = [];
	protected array $_rows = [];
	protected array $_limits = [];
	protected int $_limit  = 10;
	protected int $_page   = 1;
	protected int $_offset = 0;
	protected ?array $_error_messages = [];
	protected ?array $_alert = [];
	protected array $_select_period_options = [];
	protected array $_periods = [];
	protected DateTime $_now;
	protected IntlDateFormatter $_date_formatter;
	protected IntlDateFormatter $_datetime_formatter;
	protected IntlDateFormatter $_period_formatter;
	protected IntlDateFormatter $_month_formatter;

	function __construct(PDO $db, array $route = []) {
		$this->_db         = $db;
		$this->_controller = $route['controller'] ?? '';
		$this->_method     = $route['method'] ?? 'index';
		// Named route groups that did not take part in the match are simply absent; default them to null.
		$this->_param      = ($route['param'] ?? []) + ['locale' => null, 'id' => null, 'alias' => null, 'slug' => null];
		$this->_limits     = $this->_cached('limits', fn() => [10, 25, 50, 100]);
		$this->_now        = new DateTime;
		$_SESSION['error_messages'] ??= [];
		$_SESSION['alert']          ??= [];
		$this->_error_messages = &$_SESSION['error_messages'];
		$this->_alert          = &$_SESSION['alert'];
		foreach (['date_formatter' => 'd MMM yyyy', 'datetime_formatter' => 'd MMM yyyy HH.mm', 'period_formatter' => 'MMM yyyy', 'month_formatter' => 'MMM'] as $k => $v) {
			$this->{"_$k"} = new IntlDateFormatter('id_ID', IntlDateFormatter::LONG, IntlDateFormatter::NONE, 'UTC', IntlDateFormatter::GREGORIAN, $v);
		}
		$this->_select_period_options = $this->_cached('select_period_options', function () {
			$options = ['' => '&raquo;'];
			foreach (new DatePeriod(new DateTime('2013-01-01'), new DateInterval('P1M'), $this->_now) as $date) {
				$options[$date->format('Ym')] = $this->_period_formatter->format($date);
			}
			return $options;
		});
		$this->_periods = $this->_cached('periods', function () {
			$periods = [];
			$start   = (clone $this->_now)->setDate((int) $this->_now->format('Y') - 1, 1, 1);
			foreach (new DatePeriod($start, new DateInterval('P1M'), $this->_now) as $date) {
				$periods[$date->format('Ym')] = $this->_month_formatter->format($date);
			}
			return $periods;
		});
	}

	/** Fetches a value from APCu, computing and storing it on a cache miss (or when APCu is unavailable). */
	protected function _cached(string $key, callable $compute): mixed {
		if (function_exists('apcu_fetch')) {
			$value = apcu_fetch($key, $hit);
			if ($hit) {
				return $value;
			}
		}
		$value = $compute();
		function_exists('apcu_add') && apcu_add($key, $value);
		return $value;
	}

	/** Runs a parameterized query and returns the first column of the first row. */
	protected function _scalar(string $sql, array $params = []): mixed {
		$stmt = $this->_db->prepare($sql);
		$stmt->execute($params);
		return $stmt->fetchColumn();
	}

	/** True when no other record (ignoring the one being edited) has $value in $column. */
	protected function _unique(string $table, string $column, mixed $value): bool {
		$sql    = "SELECT COUNT(1) FROM $table WHERE \"$column\" = ?";
		$params = [$value];
		if ($this->_param['id']) {
			$sql     .= ' AND id <> ?';
			$params[] = $this->_param['id'];
		}
		return !$this->_scalar($sql . ($table === 'mv_users' ? ' AND resign IS NULL' : ''), $params);
	}

	/** Formats a "YYYYMM" period (optionally shifted by whole months) as "MMM yyyy"; empty string when missing. */
	protected function _format_period(int|string|null $period, int $add_months = 0): string {
		$date = $period ? DateTime::createFromFormat('!Ym', (string) $period) : false;
		if (!$date) {
			return '';
		}
		$add_months && $date->modify(sprintf('%+d month', $add_months));
		return (string) $this->_period_formatter->format($date);
	}

	/** Returns the validation error message for a form field, or an empty string. */
	protected function _err(string $field): string {
		return (string) ($this->_error_messages[$field] ?? '');
	}

	function index($get, $post, $files) {
		$stmt = $this->_db->prepare("SELECT r.query FROM modules m JOIN routes r ON m.id = r.module_id WHERE m.name = ? AND r.module_method = 'index'");
		$stmt->execute([static::class]);
		$this->_query = (string) $stmt->fetchColumn();
		$order_by = $get['order_by'] ?? null;
		if (is_string($order_by) && array_key_exists($order_by, $this->_order_fields)) {
			$this->_order_by = $this->_order_fields[$order_by];
			return;
		}
		$this->_order_by = $this->_order_fields[array_key_first($this->_order_fields)] ?? '1';
	}

	protected function _paginate($get, $form_action, $params = [], $fields = '') {
		$limit_index   = (int) ($get['limit'] ?? 0);
		$this->_limit  = $this->_limits[$limit_index] ?? $this->_limits[0];
		$this->_page   = max(1, (int) ($get['page'] ?? 1));
		$this->_offset = ($this->_page - 1) * $this->_limit;
		$stmt          = $this->_db->prepare(strtr($this->_query, ['*' => 'COUNT(1)']));
		$stmt->execute($params);
		$total_rows_in_db = (int) $stmt->fetchColumn();

		$fields && $this->_query = strtr($this->_query, ['*' => $fields]);
		$stmt = $this->_db->prepare($this->_query . " ORDER BY $this->_order_by LIMIT $this->_limit OFFSET $this->_offset");
		$stmt->execute($params);
		$total_rows_limited = $stmt->rowCount();
		$this->_rows        = [];
		while ($row = $stmt->fetchObject()) {
			$this->_rows[] = $row;
		}

		$this->_pagination .= '<form method="GET" action="' . $form_action . '" class="navbar-form navbar-right">';
		!empty($get['q']) && $this->_pagination .= '<input type="hidden" name="q" value="' . htmlspecialchars((string) $get['q']) . '">';
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
			$total_pages        = (int) ceil($total_rows_in_db / $this->_limit);
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
		$menu = '<li' . (($_SERVER['REQUEST_URI'] ?? '') === Utilities::link_to('about-us') ? ' class="active"' : '') . '><a href="' . Utilities::link_to('about-us') . '"><i class="fa fa-info-circle">&nbsp;</i>&nbsp;' . _('About Us') . '</a></li><li';
		if (!empty($_SESSION['user_id'])) {
			$stmt = $this->_db->prepare('SELECT alias FROM users WHERE id = ?');
			$stmt->execute([$_SESSION['user_id']]);
			$menu .= ' class="dropdown' . ($this->_controller == 'Sessions' ? ' active' : '') . '"><a class="dropdown-toggle" data-toggle="dropdown" href="#"><i class="fa fa-user">&nbsp;</i>&nbsp;' . _('Welcome') . ' ' . $stmt->fetchColumn() . '&nbsp;<b class="caret">&nbsp;</b></a><ul class="dropdown-menu"><li><a href="' . Utilities::link_to('sessions/mine') . '"><i class="fa fa-info">&nbsp;</i>&nbsp;' . _('About Me') . '</a></li><li><a href="' . Utilities::link_to('sessions/destroy') . '"><i class="fa fa-sign-out">&nbsp;</i>&nbsp;' . _('Logout') . '</a></li></ul>';
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
			$menu .= '<ul class="dropdown-menu"><li><a href="/' . (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'GET' ? preg_replace('/^\/' . preg_quote($_SESSION['locale'], '/') . '/', $k, $_SERVER['REQUEST_URI'] ?? '') : "$k/home") . '" src="/images/' . $k . '.png"> ' . $v . '</a></li></ul>';
		}
		$menu .= '</li>';
		return $menu;
	}

	protected function _db_insert($table, $data = []) {
		foreach (['created_by', 'last_modified_by'] as $k) {
			$data[$k] = $_SESSION['user_id'] ?? null;
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
		$data['modified_by'] = $_SESSION['user_id'] ?? null;
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
		return $this->_alert ? '<div class="alert alert-' . ($this->_alert['type'] ?? 'info') . '"><a class="close" href="#" data-dismiss="alert">x</a>' . ($this->_alert['message'] ?? '') . '</div>' : '';
	}

	protected function _allowed_to_access_link($controller, $method = 'index') {
		return in_array($method, $_SESSION['role_permissions'][$controller] ?? [], true);
	}
}