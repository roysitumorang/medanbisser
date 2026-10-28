<?php

class Expenses extends Application {
	function __construct($db, $route) {
		parent::__construct($db, $route);
		$this->_order_fields = $this->_cached('expenses_order_fields', fn() => ['Tanggal' => 'dot DESC']);
	}

	function index($get, $post, $files) {
		parent::index($get, $post, $files);
		$params = [];
		if (!empty($get['q'])) {
			$params = [sprintf('%%%s%%', strtolower($get['q']))];
			$this->_query .= ' WHERE LOWER(description) LIKE ?';
		}
		$this->_paginate($get, Utilities::link_to('expenses'), $params, 'id, dot, description, amount');

		$this->_content .= '
			<h2 class="navbar-form navbar-left"><i class="fa fa-shopping-basket">&nbsp;</i> ' . ngettext('Expense', 'Expenses', 2) . '</h2>
			<form method="GET" action="' . Utilities::link_to('expenses') . '" class="navbar-form navbar-right" role="search" onsubmit="(\'' . _('Search') . '\'==$(\'[name=q\').val())&amp;&amp;$(\'[name=q]\').val(\'\')">
				<input type="text" name="q" value="' . htmlspecialchars($get['q'] ?? '') . '" class="form-control" placeholder="' . _('Search') . '">
				<button type="submit" class="btn btn-default"><i class="fa fa-search">&nbsp;</i> ' . _('Search') . '</button>';

		$this->_content .= $this->_allowed_to_access_link('Expenses', 'new') ? '<a type="button" href="' . Utilities::link_to('expenses/new') . '" class="btn btn-default"><i class="fa fa-user-plus">&nbsp;</i> ' . _('New') . '</a>' : '';

		$this->_content .= '
			</form>
			<div class="clearfix"></div>' .
			$this->_pagination .
			'<table class="table table-striped table-hover table-condensed">
				<thead>
					<tr>
						<th class="text-center">' . _('Date') . '</th>
						<th class="text-center">' . _('Description') . '</th>
						<th class="text-center">' . _('Amount') . '</th>
						<th class="text-center">#</th>
					</tr>
				</thead>
				<tbody>';

		foreach ($this->_rows as $row) {
			$this->_content .=
					"<tr class=\"text-nowrap\">
						<td class=\"text-right\">" . $this->_date_formatter->format(new DateTime($row->dot)) . "</td>
						<td>{$row->description}</td>
						<td class=\"text-right\">" . number_format((float) $row->amount) . "</td>
						<td>" .
			($this->_allowed_to_access_link('Expenses', 'edit') ? "<a type=\"button\" href=\"" . Utilities::link_to("expenses/{$row->id}/edit") . "\" class=\"btn btn-primary\"><i class=\"fa fa-edit\">&nbsp;</i> " . _('Edit') . "</a>" : '') .
						"</td>
					</tr>";
		}

		$this->_content .=<<<CONTENT
				</tbody>
			</table>
			$this->_pagination
CONTENT;
	}

	function new($get, $post, $files) {
		$this->_form($get, $post, Utilities::link_to('expenses/create'));
	}

	function create($get, $post, $files) {
		$this->_validate($post, $files);
		$original_post = $post;
		if ($this->_error_messages) {
			$this->_form($get, $original_post, Utilities::link_to('expenses/create'));
			return;
		}
		krsort($post['dot']);
		$dot = (new DateTime(implode('-', $post['dot'])))->format('Y-m-d');
		$id = parent::_db_insert('expenses', array_merge($post, ['dot' => $dot]));
		$this->_alert = ['type' => 'success', 'message' => _('Expense created successfully')];
		Utilities::redirect_to("expenses/$id/edit");
	}

	function edit($get, $post, $files) {
		$expense = $this->_prepare_data();
		foreach ($expense as $k => $v) {
			if (isset($post[$k])) continue;
			if ($k == 'dot' && $v) {
				list($year, $month, $day) = explode('-', $v);
				$v = ['year' => $year, 'month' => $month, 'day' => $day];
			}
			$post[$k] = $v;
		}
		$this->_form($get, $post, Utilities::link_to("expenses/$expense->id/update"));
	}

	function update($get, $post, $files) {
		$expense = $this->_prepare_data();
		$this->_validate($post, $files);
		if ($this->_error_messages) {
			$this->_alert = ['type' => 'danger', 'message' => _('Record invalid')];
			$this->_form($get, $post, Utilities::link_to("expenses/$expense->id/update"));
			return;
		}
		krsort($post['dot']);
		$dot = (new DateTime(implode('-', $post['dot'])))->format('Y-m-d');
		parent::_db_update('expenses', array_merge($post, ['dot' => $dot]));
		$this->_alert = ['type' => 'success', 'message' => _('Expense updated successfully')];
		Utilities::redirect_to("expenses/$expense->id/edit");
	}

	private function _form($get, $post, $action) {
		$this->_content .=
		'<h2 class="navbar-form navbar-left"><i class="fa fa-shopping-basket">&nbsp;</i> ' . ngettext('Expense', 'Expenses', 1) . '</h2>
		<div class="clearfix"></div>' .
		$this->_get_form_notification() .
		'<form action="' . $action . '" method="POST" enctype="multipart/form-data" role="form">
			<input type="hidden" name="id" value="' . $this->_param['id'] . '">
			<div class="row form-inline">
				<div class="col-sm-2">
					<label for="dot" class="control-label">* ' . _('Date') . '</label>
				</div>
				<div class="col-xs-12 col-sm-6 col-md-8' . ($this->_err('dot') ? ' has-error error' : '') . '">
					<select class="form-control" id="dot_day" name="dot[day]">
						<option value="">&raquo;</option>';
					foreach (range(1, 31) as $i) {
						$d = $i < 10 ? '0' . $i : $i;
						$this->_content .= '<option value="' . $d . '"' . ($d == ($post['dot']['day'] ?? '') ? ' selected' : '') . '>' . $d . '</option>';
					}
					$this->_content .= '
					</select> - <select class="form-control" id="dot_month" name="dot[month]">
						<option value="">&raquo;</option>';
					foreach (['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'] as $k => $v) {
						$m = $k + 1;
						$m < 10 && $m = '0' . $m;
						$this->_content .= '<option value="' . $m . '"' . ($m == ($post['dot']['month'] ?? '') ? ' selected' : '') . '>' . $v . '</option>';
					}
					$this->_content .= '
					</select> - <select class="form-control" id="dot_year" name="dot[year]">
						<option value="">&raquo;</option>';
					foreach (range(2013, $this->_now->format('Y')) as $i) {
						$this->_content .= '<option value="' . $i . '"' . ($i == ($post['dot']['year'] ?? '') ? ' selected' : '') . '>' . $i++ . '</option>';
					}
					$this->_content .= '
					</select>
					<span class="help-block' . ($this->_err('dot') ? ' text-danger' : '') . '">' . $this->_err('dot') . '</span>
				</div>
			</div>
			<div class="row form-inline">
				<div class="col-sm-2">
					<label for="amount" class="control-label">* ' . _('Amount') . '</label>
				</div>
				<div class="col-xs-12 col-sm-6 col-md-8' . ($this->_err('amount') ? ' has-error error' : '') . '">
					<input id="amount" name="amount" type="text" value="' . ($post['amount'] ?? '') . '" class="form-control" placeholder="' . _('Amount') . '">
					<span class="help-block' . ($this->_err('amount') ? ' text-danger' : '') . '">' . $this->_err('amount') . '</span>
				</div>
			</div>
			<div class="row form-group">
				<div class="col-sm-2">
					<label for="description" class="control-label">* ' . _('Description') . '</label>
				</div>
				<div class="col-xs-12 col-sm-6 col-md-8' . ($this->_err('description') ? ' has-error error' : '') . '">
					<input id="description" name="description" type="text" value="' . ($post['description'] ?? '') . '" class="form-control" placeholder="' . _('Description') . '">
					<span class="help-block' . ($this->_err('description') ? ' text-danger' : '') . '">' . $this->_err('description') . '</span>
				</div>
			</div>
			<div class="form-group">
				<button type="submit" class="btn btn-primary"><i class="fa fa-save">&nbsp;</i> ' . _('Save') . '</button>
				<button type="reset" class="btn btn-danger"><i class="fa fa-undo">&nbsp;</i> ' . _('Reset') . '</button>
				<a type="button" href="' . Utilities::link_to('expenses') . '" class="btn btn-default"><i class="fa fa-step-backward">&nbsp;</i> ' . _('Back') . '</a>
			</div>
		</form>';
	}

	private function _validate($post, $files) {
		$dot_error_messages = [];
		foreach (['year' => 'tahun', 'month' => 'bulan', 'day' => 'hari'] as $k => $v) {
			empty($post['dot'][$k]) && $dot_error_messages[] = "$v " . _('is blank');
		}
		if (empty($dot_error_messages) && !checkdate((int) $post['dot']['month'], (int) $post['dot']['day'], (int) $post['dot']['year'])) {
			$dot_error_messages[] = _('is invalid');
		}
		$dot_error_messages && $this->_error_messages['dot'] = join(', ', $dot_error_messages);
		if (empty($post['amount'])) {
			$this->_error_messages['amount'] = _('is blank');
		} else if (!is_numeric($post['amount'])) {
			$this->_error_messages['amount'] = _('is invalid');
		}
		empty($post['description']) && $this->_error_messages['description'] = _('is blank');
		$this->_error_messages && $this->_alert = ['type' => 'danger', 'message' => _('Record invalid')];
	}

	private function _prepare_data() {
		$stmt = $this->_db->prepare('SELECT * FROM expenses WHERE id = ?');
		$stmt->execute([$this->_param['id']]);
		return $stmt->fetchObject() ?: Utilities::redirect_to('404');
	}
}