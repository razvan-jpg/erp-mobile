using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using ERPMobile.Services;

namespace ERPMobile.Ui;

public static class ConfirmDialog
{
    public static async Task<bool> Ask(Control owner, string message)
    {
        var window = new Window
        {
            Title = "ERP Mobile",
            Width = 420,
            Height = 180,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            CanResize = false,
            Icon = Brand.WindowIcon(),
            Background = Brushes.White
        };
        var ok = false;
        var panel = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 16 };
        panel.Children.Add(new TextBlock { Text = message, TextWrapping = TextWrapping.Wrap, Foreground = Brand.Brush(Brand.Navy) });
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Spacing = 8 };
        var cancel = new Button { Content = "Renunță", Padding = new Avalonia.Thickness(12, 6) };
        var confirm = new Button { Content = "Confirmă", Padding = new Avalonia.Thickness(12, 6), Background = Brand.Brush(Brand.Navy), Foreground = Brushes.White };
        cancel.Click += (_, _) => window.Close(false);
        confirm.Click += (_, _) => { ok = true; window.Close(true); };
        buttons.Children.Add(cancel);
        buttons.Children.Add(confirm);
        panel.Children.Add(buttons);
        window.Content = panel;
        if (TopLevel.GetTopLevel(owner) is Window parent)
            await window.ShowDialog(parent);
        else
            window.Show();
        return ok;
    }
}

public static class RecordDialog
{
    public static async Task<bool> Edit(Control owner, string title, string table, Dictionary<string, string> values, bool isNew, AppSession? session)
    {
        var window = new Window
        {
            Title = title,
            Width = 560,
            Height = 640,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Icon = Brand.WindowIcon(),
            Background = Brand.Brush(Brand.Page)
        };
        var saved = false;
        var boxes = new Dictionary<string, TextBox>();
        var checks = new Dictionary<string, CheckBox>();
        var combos = new Dictionary<string, ComboBox>();
        var relations = await LoadRelations(values.Keys, session);
        var form = new StackPanel { Spacing = 10, Margin = new Avalonia.Thickness(20) };
        foreach (var key in FieldChoices.Order(values.Keys))
        {
            var value = values[key];
            form.Children.Add(new TextBlock { Text = FieldChoices.Caption(table, key), Foreground = Brand.Brush(Brand.Muted), FontSize = 12 });
            if (IsBool(key, value))
            {
                var check = new CheckBox
                {
                    Content = "Da",
                    IsChecked = value is "Da" or "true" or "1" || (isNew && value.Length == 0 && key == "is_active")
                };
                checks[key] = check;
                form.Children.Add(check);
                continue;
            }

            List<FieldChoice>? options = null;
            if (relations.TryGetValue(key, out var related))
                options = related;
            else if (FieldChoices.Options(table, key) is { } coded)
                options = coded.ToList();

            if (options != null)
            {
                var match = FieldChoices.Match(options, value);
                if (match == null && value.Length > 0)
                {
                    match = new FieldChoice(value, value);
                    options.Insert(0, match);
                }
                else if (match == null && value.Length == 0 && FieldChoices.UseFirstWhenEmpty(table, key) && !relations.ContainsKey(key))
                    match = options.FirstOrDefault(option => option.Code.Length > 0) ?? options.FirstOrDefault();

                var combo = new ComboBox
                {
                    ItemsSource = options,
                    SelectedItem = match,
                    HorizontalAlignment = HorizontalAlignment.Stretch,
                    MinHeight = 32
                };
                combos[key] = combo;
                form.Children.Add(combo);
                continue;
            }

            var box = new TextBox { Text = value };
            boxes[key] = box;
            form.Children.Add(box);
        }
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Spacing = 8, Margin = new Avalonia.Thickness(0, 8, 0, 0) };
        var cancel = new Button { Content = "Renunță", Padding = new Avalonia.Thickness(12, 6) };
        var save = new Button { Content = isNew ? "Adaugă" : "Salvează", Padding = new Avalonia.Thickness(12, 6), Background = Brand.Brush(Brand.Gold), Foreground = Brushes.White };
        cancel.Click += (_, _) => window.Close(false);
        save.Click += (_, _) =>
        {
            foreach (var (key, box) in boxes)
                values[key] = box.Text ?? "";
            foreach (var (key, check) in checks)
                values[key] = check.IsChecked == true ? "Da" : "Nu";
            foreach (var (key, combo) in combos)
                values[key] = combo.SelectedItem is FieldChoice choice ? choice.Code : "";
            saved = true;
            window.Close(true);
        };
        buttons.Children.Add(cancel);
        buttons.Children.Add(save);
        form.Children.Add(buttons);
        window.Content = new ScrollViewer { Content = form };
        if (TopLevel.GetTopLevel(owner) is Window parent)
            await window.ShowDialog(parent);
        return saved;
    }

    private static async Task<Dictionary<string, List<FieldChoice>>> LoadRelations(IEnumerable<string> keys, AppSession? session)
    {
        var result = new Dictionary<string, List<FieldChoice>>();
        if (session?.CurrentCompany == null)
            return result;
        foreach (var key in keys.Distinct())
        {
            if (!FieldChoices.Relation(key, out var relation))
                continue;
            try
            {
                var json = await session.SelectRows(
                    relation.Table,
                    "select=id," + relation.LabelField + "&company_id=eq." + session.CurrentCompany.Id + "&order=" + relation.LabelField + ".asc&limit=1000");
                var list = new List<FieldChoice> { new("", "—") };
                if (json.ValueKind == JsonValueKind.Array)
                {
                    foreach (var row in json.EnumerateArray())
                    {
                        if (!row.TryGetProperty("id", out var idElement))
                            continue;
                        var id = idElement.GetString() ?? "";
                        if (id.Length == 0)
                            continue;
                        var label = id;
                        if (row.TryGetProperty(relation.LabelField, out var labelElement) && labelElement.ValueKind == JsonValueKind.String)
                            label = labelElement.GetString() ?? id;
                        list.Add(new FieldChoice(id, label));
                    }
                }
                result[key] = list;
            }
            catch
            {
                // Câmpul rămâne text dacă lista nu se încarcă.
            }
        }
        return result;
    }

    private static bool IsBool(string key, string value) =>
        key.StartsWith("is_", StringComparison.Ordinal) || value is "Da" or "Nu";
}

public static class CompanyDialog
{
    public static async Task<bool> Create(Control owner, Services.AppSession session)
    {
        var window = new Window
        {
            Title = "Societate nouă",
            Width = 520,
            Height = 640,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Icon = Brand.WindowIcon(),
            Background = Brushes.White
        };
        var denumire = Field();
        var cui = Field();
        var nume = Field();
        var prenume = Field();
        var email = Field();
        var parola = Field();
        parola.PasswordChar = '•';
        var cnp = Field();
        var telefon = Field();
        var error = new TextBlock { Foreground = Brushes.IndianRed, TextWrapping = TextWrapping.Wrap };
        var form = new StackPanel { Margin = new Avalonia.Thickness(20), Spacing = 8 };
        void Add(string label, TextBox box)
        {
            form.Children.Add(new TextBlock { Text = label, Foreground = Brand.Brush(Brand.Muted) });
            form.Children.Add(box);
        }
        Add("Denumire societate", denumire);
        Add("CUI", cui);
        Add("Nume administrator", nume);
        Add("Prenume administrator", prenume);
        Add("Email administrator", email);
        Add("Parolă administrator", parola);
        Add("CNP", cnp);
        Add("Telefon", telefon);
        form.Children.Add(error);
        var save = new Button { Content = "Creează societatea", Padding = new Avalonia.Thickness(12, 8), Background = Brand.Brush(Brand.Navy), Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Left };
        save.Click += async (_, _) =>
        {
            error.Text = "";
            try
            {
                await session.CreateCompany(denumire.Text?.Trim() ?? "", Empty(cui), nume.Text?.Trim() ?? "", prenume.Text?.Trim() ?? "", email.Text?.Trim() ?? "", parola.Text ?? "", Empty(cnp), Empty(telefon));
                window.Close(true);
            }
            catch (Exception ex)
            {
                error.Text = ex.Message;
            }
        };
        form.Children.Add(save);
        window.Content = new ScrollViewer { Content = form };
        var created = false;
        window.Closed += (_, _) => { };
        if (TopLevel.GetTopLevel(owner) is Window parent)
            created = await window.ShowDialog<bool>(parent);
        return created;
    }

    private static TextBox Field() => new();
    private static string? Empty(TextBox box)
    {
        var text = box.Text?.Trim();
        return string.IsNullOrEmpty(text) ? null : text;
    }
}
