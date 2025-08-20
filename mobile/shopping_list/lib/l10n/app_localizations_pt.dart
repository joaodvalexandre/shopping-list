// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Compras Inteligentes';

  @override
  String get shoppingLists => 'Listas de Compras';

  @override
  String get createNewList => 'Criar Nova Lista';

  @override
  String get listName => 'Nome da Lista';

  @override
  String get listNameRequired => 'Por favor, introduza um nome para a lista';

  @override
  String get listNameHint => 'ex., Compras, Suprimentos da Casa, Compras da Festa';

  @override
  String get create => 'Criar';

  @override
  String get update => 'Atualizar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get addItem => 'Adicionar Item';

  @override
  String get editItem => 'Editar Item';

  @override
  String get itemName => 'Nome do Item';

  @override
  String get itemNameRequired => 'Por favor, introduza um nome para o item';

  @override
  String get itemNameHint => 'ex., Leite, Pão, Maçãs';

  @override
  String get quantity => 'Quantidade';

  @override
  String get quantityHint => '1';

  @override
  String get add => 'Adicionar';

  @override
  String get deleteList => 'Eliminar Lista de Compras';

  @override
  String get deleteListConfirm => 'Tem a certeza que quer eliminar esta lista de compras? Esta ação não pode ser desfeita.';

  @override
  String get deleteItem => 'Eliminar Item';

  @override
  String deleteItemConfirm(Object itemName) {
    return 'Tem a certeza que quer eliminar \"$itemName\"?';
  }

  @override
  String get addToCart => 'Adicionar ao Carrinho';

  @override
  String get removeFromCart => 'Remover do Carrinho';

  @override
  String get markAllAsPurchased => 'Marcar Todos como Comprados';

  @override
  String get markAllAsPurchasedConfirm => 'Marcar todos os itens no carrinho como comprados?';

  @override
  String get connection => 'Ligação';

  @override
  String get webapp => 'Aplicação Web';

  @override
  String get sync => 'Sincronizar';

  @override
  String get offline => 'Offline';

  @override
  String get online => 'Online';

  @override
  String get available => 'Disponível';

  @override
  String get unavailable => 'Indisponível';

  @override
  String get pending => 'pendente';

  @override
  String get upToDate => 'Atualizado';

  @override
  String get changes => 'alterações';

  @override
  String get noChanges => 'Sem alterações';

  @override
  String get import => 'Importar';

  @override
  String get syncOfflineChanges => 'Sincronizar Alterações Offline';

  @override
  String get forceRefresh => 'Atualização Forçada';

  @override
  String get forceRefreshConfirm => 'Isto irá descarregar todos os dados da aplicação web e sobrescrever quaisquer alterações locais. Esta ação não pode ser desfeita. Tem a certeza que quer continuar?';

  @override
  String get forceRefreshTitle => 'Atualização Forçada da Aplicação Web';

  @override
  String get noShoppingLists => 'Nenhuma lista de compras encontrada';

  @override
  String get noShoppingListsHint => 'Crie a sua primeira lista de compras para começar!';

  @override
  String get checkWebappConnection => 'Verificar ligação à aplicação web';

  @override
  String get toBuy => 'Para Comprar';

  @override
  String get inCart => 'No Carrinho';

  @override
  String get purchased => 'Comprado';

  @override
  String get totalLists => 'Total de Listas';

  @override
  String get totalItems => 'Total de Itens';

  @override
  String get itemsInCart => 'Itens no Carrinho';

  @override
  String get itemsPurchased => 'Itens Comprados';

  @override
  String get selectLanguage => 'Selecionar Idioma';

  @override
  String get english => 'Inglês';

  @override
  String get portuguese => 'Português';

  @override
  String get changeLanguage => 'Alterar Idioma';

  @override
  String get editList => 'Editar Lista';
}
