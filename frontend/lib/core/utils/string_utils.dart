class StringUtils {
  /// Formata e capitaliza cada palavra do nome de exibição do usuário.
  static String formatDisplayName(String name) {
    if (name.isEmpty) return name;
    
    // Divide por espaços, capitaliza cada palavra e junta novamente.
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
